---
name: "astro-content-performance"
description: "Astro's entire performance pitch is \"ship HTML, not JavaScript\" — but that promise only holds if every component's hydration strategy is a deliberate choice, not a default habit carried over from a client-rendered framew"
source_type: "skill"
source_file: "skills/astro-content-performance.md"
---

# astro-content-performance

Migrated from `skills/astro-content-performance.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Fix Unnecessary Hydration and Unoptimized Images Hurting Core Web Vitals

Astro's entire performance pitch is "ship HTML, not JavaScript" — but that promise only holds if every component's hydration strategy is a deliberate choice, not a default habit carried over from a client-rendered framework. On a marketing/candidate-acquisition site, the two most common regressions are the same two things every time: components hydrating with `client:load` when they didn't need to hydrate at all, and hero images shipped unoptimized, blowing the Largest Contentful Paint (LCP) budget before the fold even renders.

## Problem

A team migrates a marketing site to Astro, sees `.astro` files, and starts treating them like React components — reaching for `client:load` on everything "to be safe." The result is a site that renders identical HTML to a client-rendered SPA but now also ships the SPA's JS bundle on top of it, plus large unoptimized images with no explicit dimensions.

```astro
---
// BAD: pages/index.astro
import Header from '../components/Header.tsx';
import Hero from '../components/Hero.tsx';
import Testimonials from '../components/Testimonials.tsx';
import Footer from '../components/Footer.tsx';
---
<Header client:load />        <!-- Static nav — never needs to hydrate at all -->
<Hero client:load />           <!-- Static copy + a raw <img>, no interactivity -->
<Testimonials client:load />   <!-- Below the fold, hydrates immediately anyway -->
<Footer client:load />         <!-- Static links -->

<!-- Every one of these ships and executes React + component JS on first load,
     even though nothing on the page requires client-side interactivity yet -->
```

```astro
---
// BAD: Hero.tsx renders a raw <img> for the largest above-the-fold element
---
<img src="/hero-photo.jpg" class="hero-image" />
<!-- No width/height → browser can't reserve layout space → CLS
     No format negotiation → ships a large JPEG to every device → poor LCP -->
```

## Solution

### Choosing the Right `client:` Directive

```astro
---
// src/pages/careers/index.astro
import StaticHero from '../../components/sections/Hero.astro';        // no directive
import JobFilter from '../../components/islands/JobFilter.tsx';        // interactive
import CookieBanner from '../../components/islands/CookieBanner.tsx';  // low priority
import Testimonials from '../../components/islands/Testimonials.tsx';  // below fold
---
<!-- No directive: pure static markup, zero JS shipped for this component -->
<StaticHero />

<!--
  client:load — only for components that must be interactive the instant
  the page paints. Reserve this for small, critical widgets (nav toggle,
  above-the-fold search). This page has nothing that urgent, so it's omitted.
-->

<!--
  client:idle — hydrate once the main thread is free. Good for anything
  useful-but-not-urgent that shouldn't compete with initial render.
-->
<CookieBanner client:idle />

<!--
  client:visible — defer hydration until the element enters the viewport.
  Correct default for anything below the fold: carousels, embedded widgets,
  "load more" sections.
-->
<Testimonials client:visible />
<JobFilter client:visible />

<!--
  client:media — hydrate only when a media query matches, e.g. a mobile-only
  hamburger menu that a desktop visitor never needs to pay for.
-->
<!-- <MobileNav client:media="(max-width: 768px)" /> -->

<!--
  client:only="react" — skips server rendering entirely. Reserve for
  components that depend on browser-only APIs (e.g. a map that needs
  `window`) and would error during SSR.
-->
```

**Quick reference:**

| Directive | Hydrates when | Use for |
|-----------|---------------|---------|
| *(none)* | never — static HTML only | Anything with no client-side state or events |
| `client:load` | immediately on page load | Small, critical, above-the-fold interactivity |
| `client:idle` | when the main thread is idle (`requestIdleCallback`) | Useful-but-not-urgent widgets |
| `client:visible` | when the element enters the viewport | Below-the-fold components |
| `client:media` | when a media query matches | Responsive-only components (mobile nav, etc.) |
| `client:only` | skips SSR entirely, client-render only | Browser-API-dependent components |

### Image Optimization with `astro:assets`

```astro
---
// src/components/sections/Hero.astro — the LCP element on the homepage
import { Image } from 'astro:assets';
import heroPhoto from '../../assets/hero-photo.jpg';
---
<section class="hero">
  <Image
    src={heroPhoto}
    alt="Our team collaborating in the office"
    widths={[640, 1024, 1600, 2000]}
    sizes="100vw"
    format="avif"
    quality="high"
    loading="eager"
    fetchpriority="high"
  />
  <!--
    loading="eager" + fetchpriority="high" for the LCP candidate specifically —
    this is the one image on the page that should NOT lazy-load.
    Every other image on the page should use the defaults (loading="lazy").
  -->
  <h1>Build the future with us</h1>
</section>
```

```astro
---
// Below-the-fold images: let Astro's defaults do the work (lazy by default)
import { Image } from 'astro:assets';
import teamPhoto from '../../assets/team-photo.jpg';
---
<Image src={teamPhoto} alt="Engineering team offsite" width={800} height={533} />
<!-- loading="lazy" and decoding="async" are Astro's defaults — don't override
     them for anything that isn't the LCP candidate -->
```

### Content Collections for Structured, Type-Safe Content

```typescript
// src/content/config.ts
import { defineCollection, z } from 'astro:content';

const companyPages = defineCollection({
  type: 'content',
  schema: ({ image }) =>
    z.object({
      title: z.string(),
      summary: z.string().max(160), // enforce SEO-friendly description length at build time
      heroImage: image(),
      order: z.number().int().default(0),
    }),
});

export const collections = { companyPages, /* jobs, team, posts, ... */ };
```

Rendering structured content this way means the schema itself catches regressions before they ship: a missing `heroImage`, an oversized `summary`, or a typo'd `order` field fails the build instead of shipping a broken card to production.

## Why This Works

- **Astro components are HTML by default; hydration is opt-in, not opt-out.** Omitting `client:*` entirely is a completely valid, and usually correct, choice — it is not "forgetting" a directive, it's the fastest possible option.
- **`client:visible` and `client:idle` align JS execution with actual user attention.** A component the user hasn't scrolled to yet has no business competing for main-thread time during initial render; deferring it improves Total Blocking Time without changing what the user ultimately sees.
- **`astro:assets` generates responsive `srcset`/`sizes` and modern formats (AVIF/WebP) automatically**, and — critically — always emits explicit width/height, which lets the browser reserve layout space before the image loads. That is the direct fix for CLS caused by images.
- **`fetchpriority="high"` + `loading="eager"` on exactly one image (the LCP candidate) tells the browser to prioritize the resource that actually gates the Largest Contentful Paint metric**, while every other image stays lazy and out of the critical path.
- **Content Collections validate structure at build time**, converting an entire category of "content author made a typo" production bugs into build failures that are caught in CI, before they ever affect a real visitor's Core Web Vitals or SEO.

## Edge Cases & Pitfalls

### Hydration Pitfalls

- **`client:visible` on an element that's already in the initial viewport on large screens**: the directive still works correctly (it checks actual visibility), but don't assume "below the fold" is universal — test at common breakpoints, since a component that's off-screen on mobile may be visible immediately on a wide desktop viewport.
- **Wrapping a static section in an interactive component "just in case"**: if only one small piece of a section needs interactivity (e.g. one button inside an otherwise static card), extract just that button into its own island rather than hydrating the whole card.
- **Using `client:only` when SSR would have worked fine**: `client:only` means the server sends no markup for that component at all — search engine crawlers and users with slow JS see nothing there until hydration completes. Reserve it strictly for components that cannot render server-side.

### Image Pitfalls

- **Marking every image `fetchpriority="high"`**: this defeats the purpose — the browser can only truly prioritize a small number of resources meaningfully. Reserve `high` priority for the actual LCP element, confirmed via Lighthouse/PageSpeed's "Largest Contentful Paint element" callout, not a guess.
- **Using `format="avif"` without a fallback for older browsers**: `<Image>` doesn't auto-generate a `<picture>` fallback chain unless you use `<Picture>` instead; for critical hero images where broad compatibility matters, prefer `<Picture>` with multiple `format` entries.
- **Referencing remote images without configuring `image.domains`/`image.remotePatterns` in `astro.config.mjs`**: Astro's image optimization only processes local assets and explicitly allow-listed remote sources — an unlisted remote URL either fails the build or silently skips optimization depending on configuration.

### Content Collections Pitfalls

- **Forgetting `astro sync` after changing a schema**: generated types (`astro:content` module) go stale, and editors show incorrect autocomplete until sync runs — CI should run `astro check` (which triggers sync) to catch this.
- **Putting a `.max()`/`.min()` constraint too late**: validating `summary.length <= 160` in the schema is far cheaper than discovering a truncated OG description in production. Push constraints into the Zod schema wherever the value flows into `<meta>` tags.

### Core Web Vitals Specifics

- **Web fonts causing CLS**: a `@font-face` swap after custom fonts load can reflow text. Use `font-display: optional` or preload the critical font file, and size fallback fonts to closely match the loaded font's metrics.
- **Third-party embeds (chat widgets, analytics) blocking TBT**: these almost always belong behind `client:idle` or a `<script>` with `defer`, never eagerly loaded in `<head>`.

## Verification

```bash
# Build and inspect the client JS output — a mostly-static marketing site
# should have a small number of small island bundles, not one large bundle
npx astro build
ls -la dist/_astro/*.js

# Type-check Content Collections schemas and catch stale generated types
npx astro check

# Run Lighthouse against the production build (not dev server — dev is unoptimized)
npx astro preview &
npx lighthouse http://localhost:4321/ --view

# Confirm the LCP element is the intended hero image, not something else
# Lighthouse report → Performance → "Largest Contentful Paint element"
```

- [ ] No component uses `client:load` unless it's small, critical, and above the fold.
- [ ] Every below-the-fold interactive component uses `client:visible` or `client:idle`.
- [ ] The homepage's actual LCP element (per Lighthouse) has `loading="eager"` and `fetchpriority="high"`; every other image is lazy.
- [ ] All local images render through `astro:assets`, not bare `<img src>`.
- [ ] `astro check` passes with no stale Content Collections type errors.
- [ ] Lighthouse Performance score and Core Web Vitals (LCP, CLS, INP) meet the project's budget on both mobile and desktop throttling profiles.
- [ ] JS bundle size for a representative page is inspected and every shipped chunk maps to an intentional island.

## References

- [Astro: Client Directives](https://docs.astro.build/en/reference/directives-reference/#client-directives)
- [Astro: Images](https://docs.astro.build/en/guides/images/)
- [Astro: Content Collections](https://docs.astro.build/en/guides/content-collections/)
- [web.dev: Core Web Vitals](https://web.dev/articles/vitals)
- [web.dev: Optimize Largest Contentful Paint](https://web.dev/articles/optimize-lcp)
- [web.dev: Optimize Cumulative Layout Shift](https://web.dev/articles/optimize-cls)
