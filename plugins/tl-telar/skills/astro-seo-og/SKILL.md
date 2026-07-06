---
name: "astro-seo-og"
description: "A public marketing or candidate-acquisition site lives or dies by two channels it doesn't control the UI for: search engine result pages and social link previews. Both are driven entirely by `<head>` metadata that is eas"
source_type: "skill"
source_file: "skills/astro-seo-og.md"
---

# astro-seo-og

Migrated from `skills/astro-seo-og.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Fix Missing, Inconsistent, or Wrong SEO and Open Graph Metadata

A public marketing or candidate-acquisition site lives or dies by two channels it doesn't control the UI for: search engine result pages and social link previews. Both are driven entirely by `<head>` metadata that is easy to get right on one page and silently wrong on the next fifty, especially once locales, pagination, and dynamic job postings enter the picture. This skill covers a single reusable `<SEO />`/`<Layout />` pattern that makes correctness the default, plus the sitemap, robots.txt, and structured data pieces that go with it.

## Problem

Each page hand-rolls its own `<head>` block, or copies a previous page's block and forgets to update every field. The result: og:title that doesn't match `<title>`, missing og:image so the link preview falls back to a favicon or nothing, canonical URLs that point at the wrong locale or a trailing-slash variant, and job postings that never surface in Google's dedicated job search UI because there's no `JobPosting` structured data at all.

```astro
---
// BAD: pages/careers/senior-backend-engineer.astro
// Hand-written head block, copied from another page and half-updated
---
<html lang="en">
<head>
  <title>Careers</title> <!-- Generic, doesn't mention the role -->
  <meta name="description" content="Join our team!" />
  <!-- No canonical tag at all -->
  <meta property="og:title" content="Senior Backend Engineer" /> <!-- Doesn't match <title> -->
  <!-- No og:image, og:type, og:url, og:locale -->
  <!-- No twitter:card -->
  <!-- No JSON-LD JobPosting — this role will never appear in Google Jobs -->
</head>
```

```astro
---
// BAD: locale variants built by copy-pasting the English page
// pages/tr/careers/senior-backend-engineer.astro
---
<head>
  <title>Senior Backend Engineer</title> <!-- Forgot to translate -->
  <link rel="canonical" href="https://example.com/careers/senior-backend-engineer" />
  <!-- Canonical points at the English URL, telling Google to ignore this page entirely -->
</head>
```

## Solution

### A Single Source of Truth: `<SEO />`

```astro
---
// src/components/seo/SEO.astro
export interface Props {
  title: string;
  description: string;
  ogType?: 'website' | 'article' | 'profile';
  ogImage?: string;      // absolute or site-relative path; falls back to a default
  noindex?: boolean;
  publishedTime?: string; // ISO date, for ogType: 'article'
}

const {
  title,
  description,
  ogType = 'website',
  ogImage = '/og/default.png',
  noindex = false,
  publishedTime,
} = Astro.props;

// Astro.site must be set in astro.config.mjs for this to resolve correctly
const siteUrl = new URL(Astro.site ?? 'https://example.com');
const canonicalURL = new URL(Astro.url.pathname, siteUrl);
const absoluteOgImage = new URL(ogImage, siteUrl);

// Astro's i18n currentLocale gives the active locale for the current route.
// og:locale needs a real language_TERRITORY pair — do NOT derive the territory
// from the language code (e.g. `en` -> `en_EN` is invalid; it must be `en_US`).
// Map every locale your site supports explicitly instead.
const OG_LOCALE_MAP: Record<string, string> = {
  en: 'en_US',
  tr: 'tr_TR',
};
const locale = Astro.currentLocale ?? 'en';
const ogLocale = locale.includes('-') ? locale.replace('-', '_') : (OG_LOCALE_MAP[locale] ?? 'en_US');

const fullTitle = `${title} | Acme Careers`;
---
<title>{fullTitle}</title>
<meta name="description" content={description} />
<link rel="canonical" href={canonicalURL} />
{noindex && <meta name="robots" content="noindex, nofollow" />}

<!-- Open Graph -->
<meta property="og:title" content={fullTitle} />
<meta property="og:description" content={description} />
<meta property="og:type" content={ogType} />
<meta property="og:url" content={canonicalURL} />
<meta property="og:image" content={absoluteOgImage} />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:locale" content={ogLocale} />
<meta property="og:site_name" content="Acme" />
{ogType === 'article' && publishedTime && (
  <meta property="article:published_time" content={publishedTime} />
)}

<!-- Twitter Card -->
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content={fullTitle} />
<meta name="twitter:description" content={description} />
<meta name="twitter:image" content={absoluteOgImage} />
```

```astro
---
// src/layouts/BaseLayout.astro — every page goes through this, never <head> by hand
import SEO from '../components/seo/SEO.astro';

export interface Props {
  title: string;
  description: string;
  ogType?: 'website' | 'article' | 'profile';
  ogImage?: string;
}
const { title, description, ogType, ogImage } = Astro.props;
---
<html lang={Astro.currentLocale ?? 'en'}>
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <SEO title={title} description={description} ogType={ogType} ogImage={ogImage} />
</head>
<body>
  <slot />
</body>
</html>
```

### JSON-LD Structured Data: Organization + JobPosting

```astro
---
// src/components/seo/JsonLd.astro
export interface OrganizationData {
  name: string;
  url: string;
  logo: string;
  sameAs?: string[]; // LinkedIn, X, GitHub org URLs
}

export interface JobPostingData {
  title: string;
  description: string;      // required by Google's Rich Results check — plain text or HTML
  datePosted: string;       // ISO 8601
  validThrough?: string;    // ISO 8601
  employmentType: string;   // FULL_TIME | PART_TIME | CONTRACTOR | INTERN
  jobLocation: string;
  baseSalary?: { min: number; max: number; currency: string };
}

interface Props {
  type: 'Organization' | 'JobPosting';
  data: OrganizationData | JobPostingData;
}

const { type, data } = Astro.props;

const jsonLd =
  type === 'Organization'
    ? {
        '@context': 'https://schema.org',
        '@type': 'Organization',
        ...(data as OrganizationData),
      }
    : (() => {
        const job = data as JobPostingData;
        return {
          '@context': 'https://schema.org',
          '@type': 'JobPosting',
          title: job.title,
          description: job.description, // required — Rich Results fails the item without it
          datePosted: job.datePosted,
          validThrough: job.validThrough,
          employmentType: job.employmentType,
          hiringOrganization: {
            '@type': 'Organization',
            name: 'Acme',
            url: 'https://example.com', // the org's own homepage goes in `url`, not `sameAs`
            sameAs: ['https://linkedin.com/company/acme', 'https://x.com/acme'], // sameAs is for external profile references
          },
          jobLocation: {
            '@type': 'Place',
            address: { '@type': 'PostalAddress', addressLocality: job.jobLocation },
          },
          ...(job.baseSalary && {
            baseSalary: {
              '@type': 'MonetaryAmount',
              currency: job.baseSalary.currency,
              value: {
                '@type': 'QuantitativeValue',
                minValue: job.baseSalary.min,
                maxValue: job.baseSalary.max,
                unitText: 'YEAR',
              },
            },
          }),
        };
      })();
---
<script type="application/ld+json" set:html={JSON.stringify(jsonLd)} />
```

### Dynamic OG Image Generation

Two viable approaches — pick based on whether images vary per request or can be known at build time:

```typescript
// GOOD (preferred for a mostly-static site): generate OG images at build time
// scripts/generate-og-images.ts, run as part of the build via a package.json script
import { ImageResponse } from '@vercel/og';
import { getCollection } from 'astro:content';
import fs from 'node:fs/promises';

const jobs = await getCollection('jobs');

for (const job of jobs) {
  const image = new ImageResponse(
    // JSX-like template describing the 1200x630 card
    OgCardTemplate({ title: job.data.title, subtitle: job.data.department }),
    { width: 1200, height: 630 }
  );
  const buffer = Buffer.from(await image.arrayBuffer());
  await fs.writeFile(`./public/og/jobs/${job.slug}.png`, buffer);
}
// Result: a static file per job, served by the CDN, zero per-request cost
```

```typescript
// ACCEPTABLE ONLY IF the site runs SSR/hybrid and images truly need
// request-time data (e.g. A/B campaign variants). Otherwise avoid this
// on a marketing site — it adds latency and compute to every social crawl hit.
// src/pages/og/[...slug].png.ts
import type { APIRoute } from 'astro';
import { ImageResponse } from '@vercel/og';

export const prerender = false;

export const GET: APIRoute = async ({ params }) => {
  return new ImageResponse(OgCardTemplate({ title: params.slug ?? '' }), {
    width: 1200,
    height: 630,
  });
};
```

### Sitemap and robots.txt

```javascript
// astro.config.mjs
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://example.com', // required — sitemap and canonical URLs both depend on this
  integrations: [
    sitemap({
      i18n: {
        defaultLocale: 'en',
        locales: { en: 'en-US', tr: 'tr-TR' },
      },
      filter: (page) => !page.includes('/draft/'), // exclude unpublished job previews
    }),
  ],
  i18n: {
    locales: ['en', 'tr'],
    defaultLocale: 'en',
    routing: {
      prefixDefaultLocale: false, // en at /, tr at /tr/ — decide once, keep it consistent
    },
  },
});
```

```text
# public/robots.txt
User-agent: *
Allow: /
Disallow: /draft/
Disallow: /api/

Sitemap: https://example.com/sitemap-index.xml
```

## Why This Works

- **A single `<SEO />` component makes drift impossible by construction.** Every field — title, description, canonical, OG, Twitter — is derived from the same props in one place, so `og:title` can never silently diverge from `<title>` again.
- **`Astro.url` + `Astro.site` compute the canonical URL correctly for every route**, including nested and locale-prefixed ones, instead of a hardcoded string that breaks the moment a page moves.
- **Build-time OG image generation matches the site's own rendering model.** A careers site with a few hundred job postings doesn't need per-request image rendering; generating all images once at build time is faster, cheaper, and cacheable at the CDN edge exactly like the HTML.
- **`JobPosting` JSON-LD is not optional for a candidate-acquisition site** — it's the documented, required schema for a role to be eligible for Google's dedicated job search experience, which is a meaningful acquisition channel outside normal blue-link search results.
- **`@astrojs/sitemap`'s i18n option emits `xhtml:link rel="alternate" hreflang`** entries automatically, which is what tells search engines which locale variant to serve to which audience — hand-writing this per page is error-prone at scale.

## Edge Cases & Pitfalls

### Canonical URL Pitfalls

- **Trailing slash mismatches**: If `astro.config.mjs` sets `trailingSlash: 'always'` but a canonical is built from `Astro.url.pathname` before Astro normalizes it, you can end up with `/careers` and `/careers/` treated as different canonical targets. Always build the canonical from the final resolved `Astro.url`, and set `trailingSlash` explicitly rather than leaving it on `'ignore'` (the default), which allows both forms to coexist and dilutes ranking signals across duplicates.
- **Locale pages canonicalizing to the default locale**: Copy-pasting a page's `<head>` into a new locale folder without updating the canonical URL tells search engines the translated page is a duplicate of the English one — it will never rank. Each locale variant needs its own canonical pointing at itself, plus `hreflang` alternates pointing at every other locale (handled by `@astrojs/sitemap`'s `i18n` config above).
- **Paginated list pages** (e.g. `/careers?page=2`) should canonicalize to themselves, not back to page 1 — collapsing them loses indexing for jobs that only appear on later pages.

### Open Graph / Twitter Card Pitfalls

- **Relative image URLs**: `og:image` must be an absolute URL. Crawlers (Slack, LinkedIn, iMessage) do not resolve relative paths against the page URL reliably. Always build it with `new URL(path, Astro.site)`.
- **Image dimensions omitted**: Without `og:image:width`/`og:image:height`, some crawlers fetch the image before deciding how to lay out the preview card, adding latency or causing a fallback to no image at all. Always emit both, matching the actual generated image (1200×630 is the safe default aspect ratio).
- **`og:locale` format**: Must be `language_TERRITORY` (e.g. `en_US`, `tr_TR`), not a bare BCP-47 tag like `en` or `en-US`. Astro's `Astro.currentLocale` returns BCP-47 — convert it (see `SEO.astro` above) before emitting.

### Structured Data Pitfalls

- **Stale `validThrough` dates**: Google penalizes indexing of expired job postings. If a role closes, either remove the `JobPosting` JSON-LD from that page or update `validThrough` — don't leave an old date sitting in production indefinitely.
- **Missing required `JobPosting` fields**: `title`, `description`, `datePosted`, `hiringOrganization`, and `jobLocation` (or `jobLocationType: TELECOMMUTE` for fully remote roles) are required for Google Jobs eligibility. Salary is optional but strongly recommended — Google surfaces it directly in the results UI.

### Common Mistakes

- Setting `Astro.site` in `astro.config.mjs` for production but forgetting it in preview/staging configs, causing canonical URLs and sitemap entries to point at `localhost` or the wrong staging domain when a preview deploy gets indexed by accident.
- Using `noindex` inconsistently — e.g. draft job postings excluded from the sitemap but still missing a `<meta name="robots" content="noindex">`, so they're crawlable and indexable even though they're not listed anywhere.
- Forgetting to add the `Sitemap:` line to `robots.txt` — `@astrojs/sitemap` generates the file but does not wire up discovery on its own.

## Verification

```bash
# Build and confirm the sitemap was generated
npx astro build
ls dist/sitemap-index.xml dist/sitemap-0.xml

# Spot-check canonical + OG tags for a built page
grep -E 'canonical|og:|twitter:' dist/careers/senior-backend-engineer/index.html

# Validate JSON-LD structured data
# Paste the built page's <script type="application/ld+json"> block into:
# https://search.google.com/test/rich-results

# Validate Open Graph rendering as social platforms will see it:
# https://developers.facebook.com/tools/debug/ (og:* tags)
# https://cards-dev.twitter.com/validator (twitter:* tags)
```

- [ ] Every page's `<title>` and `og:title` match (same underlying value, not independently written).
- [ ] `og:image` resolves to an absolute URL and returns 200 with a 1200×630 (or documented) image.
- [ ] Canonical URL for each locale variant points at itself, not the default locale.
- [ ] `sitemap-index.xml` includes `hreflang` alternates for every locale of every page.
- [ ] `robots.txt` disallows draft/preview routes and references the sitemap.
- [ ] JobPosting pages pass Google's Rich Results Test with no missing required fields.
- [ ] `validThrough` is absent or updated for every currently-open job posting.

## References

- [Astro: Sitemap Integration](https://docs.astro.build/en/guides/integrations-guide/sitemap/)
- [Astro: Internationalization (i18n) Routing](https://docs.astro.build/en/guides/internationalization/)
- [Astro: Images](https://docs.astro.build/en/guides/images/)
- [The Open Graph Protocol](https://ogp.me/)
- [Google: JobPosting Structured Data](https://developers.google.com/search/docs/appearance/structured-data/job-posting)
- [Google: Canonicalization](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls)
- [schema.org: JobPosting](https://schema.org/JobPosting)
