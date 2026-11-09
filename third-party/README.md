# Third-party design skills and tools

Telar ships two third-party skill sets as pinned copies, and documents three more that you can install yourself.
Exact upstream commits, local modifications and the update procedure are in [`SOURCES.md`](SOURCES.md). Licenses are
in [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

| Item | Mode | What it is for |
|---|---|---|
| [dimensional-drawing](#dimensional-drawing-vendored) | vendored | Monochrome spec sheets / redlines of a component, optional motion film |
| [design.how](#designhow-vendored) | vendored | Extract, audit, document and review a design system in a shipped web app |
| [brand-identity](#brand-identity-reference-only) | reference-only | Logo + type + palette sets from one brief, plus a brand guidelines kit |
| [oil-ui](#oil-ui-reference-only--warning) | reference-only, **warning** | Visual design direction and style exploration |
| [Awwwards MCP](#awwwards-mcp-reference-only-optional) | reference-only, optional | Award-site inspiration, page/motion evidence, build-vs-reference scoring |

## dimensional-drawing (vendored)

`skills/third-party/dimensional-drawing/`, from [enesozturk/dimensional-drawing](https://github.com/enesozturk/dimensional-drawing), MIT.

| Telar id | Upstream name | Use for |
|---|---|---|
| `dd-dimensional-drawing` | `dimensional-drawing` | An Apple-style monochrome dimensional drawing of a UI component or physical product: one HTML sheet with variable-coded spacing/size/radius tables. |
| `dd-dimensional-drawing-motion` | `dimensional-drawing-motion` | **Optional.** Turns a finished sheet into a ~10 s film. The headless path needs Node 18+, Playwright with a headless Chromium (`npm install` downloads it) and ffmpeg. Telar installs none of it. |

The example sheets and the headless player load the Arimo font from Google Fonts.

## design.how (vendored)

`skills/third-party/design.how/`, from [arla6ka/design.how](https://github.com/arla6ka/design.how), MIT. Five of its
workflow skills only, for **browser-rendered web apps**. Ids carry a `dh-` prefix; the skill bodies still name each
other by their upstream names.

| Telar id | Upstream name | Use for |
|---|---|---|
| `dh-design-system-boss` | `design-system-boss` | Routing a vague whole-app design-system ask to one playbook or sibling skill |
| `dh-build-design-system` | `build-design-system` | Building a design system out of UI the app already ships: inventory, guarded captures, tokens, components, `check-system.mjs` lint |
| `dh-token-mapping` | `token-mapping` | Read-only report of how hardcoded values map onto the existing token list |
| `dh-component-docs` | `component-docs` | One existing component's documentation entry, sourced from code, stories and call sites |
| `dh-ui-review` | `ui-review` | Ranked, render-first critique of a screen or flow before shipping |

**Which skill: Telar's own or design.how?**

| Need | Use |
|---|---|
| Author or re-architect a token system (layers, Tailwind v4 `@theme`, codegen, whitelabel) | `web-design-system-tokens`, `tailwind-v4-design-tokens` |
| Audit how existing hardcoded values map onto the token list (read-only) | `dh-token-mapping` |
| Persist a mobile design system (MASTER.md + per-screen overrides) | `design-system-persistence` |
| Extract a system from a web app that already ships UI, with before/after evidence and a lint | `dh-build-design-system` |
| Compose and theme shadcn/Radix primitives | `shadcn-component-patterns` |
| Write one existing component's sourced doc entry | `dh-component-docs` |
| Move an app onto an existing design system | `web-design-system-architect` agent, normal Telar flow, one owner-approved commit per surface |
| Formal WCAG 2.2 AA conformance | `web-accessibility-expert` agent |
| Ranked UX critique with a ship verdict | `dh-ui-review` |

**Requirements and limits**

- The capture and pixel-diff scripts need Node, Playwright and a Chromium. `find-chromium.mjs` finds one or prints
  install advice; it installs nothing itself.
- **Telar's git policy wins** over any step that cuts a branch or commits. The skills defer to CLAUDE.md / AGENTS.md.
- **Migration is not shipped.** Telar does not vendor design.how's `migrate-design-system` skill or its `land.mjs`
  landing script. `land.mjs` commits with no prompt, once per surface, and can run an arbitrary `sh -c` command from
  `--bodies-check` or `LAND_BODIES_CHECK`. Where `dh-design-system-boss` or `dh-build-design-system` would hand off to
  that migration, Telar uses its normal flow instead: `web-design-system-architect`, with one owner-approved commit
  per surface. Adapter notes at the top of both skills say so.
- Script review notes (unguarded status preflight in `capture.mjs`, captured request bodies in capture logs) are
  listed in [`SOURCES.md`](SOURCES.md#vendored-file-review-notes-2026-11-09).

## brand-identity (reference-only)

[fatihaydost/brand-identity-skill](https://github.com/fatihaydost/brand-identity-skill), MIT. It ships its own
`THIRD_PARTY_NOTICES.md`. Telar does not copy it. From one brief it builds three or four brand identity sets, each with a
logo, typography and palette. It measures contrast, colour-blindness, glyph coverage, font licences and small-size logo
renders. It then exports a brand guidelines kit (PDF, logo files, design tokens) for the set you pick.

Install it through its plugin marketplace:

```text
/plugin marketplace add fatihaydost/brand-identity-skill
/plugin install brand-identity@brand-identity-skill
```

Requirements: Python 3.10+, a Chromium-based browser, and ideally `uv`. Its README says it contacts Google Fonts, the
google/fonts repository, PyPI (once, through uv) and any site URLs you give it. It also says it has no telemetry.
Trademark clearance of a generated logo is your responsibility. If it is installed, use it before tokens exist. Hand
the chosen palette and type to `web-design-system-architect` or `mobile-design-system-architect`.

## oil-ui (reference-only, warning)

[oil-oil/oil-ui](https://github.com/oil-oil/oil-ui), MIT. **Telar does not ship oil-ui and does not route to it.**
You may install it yourself at your own risk. We reviewed commit `16b3057` on 2026-11-09 and found:

- **It runs a network call when it loads.** `SKILL.md` contains a load-time shell hook
  (`` !`sh "${CLAUDE_SKILL_DIR}/scripts/check_update.sh"` ``) and pre-approves it in `allowed-tools`. That script runs
  `check_update.py`, which calls `ui.oiloil.org` (or `$OIL_API`) at most once every 10 minutes. It reads `OIL_TOKEN`
  or the oil CLI token in `~/.config/oil/config.json` (`%APPDATA%\oil\config.json` on Windows), and keeps state under
  `~/.local/state/oil/`. It is skipped only when `OIL_NO_UPDATE_CHECK` is set or the skill lives in a git checkout.
- **It can update itself.** `check_update.py --update` runs `npx -y github:oil-oil/oil-cli#<pinned sha> update`, which
  rewrites the installed skill in place.
- **It upsells.** When a task touches Pro-only areas, the skill tells the agent to mention the paid "Oil UI Pro" at the
  end of a reply. `scripts/recommend_once.py` also prints a one-time Pro recommendation per user.
- **It sends a token.** `scripts/oiloil-image.mjs` sends your token as `Authorization: Bearer …` to `api.oiloil.org`
  (or `$OIL_IMAGE_API`) for paid image credits.
- **Some of its media is non-commercial only.** `scripts/curate-media.mjs` pulls from museum and archive APIs (V&A,
  Met, AIC, Cleveland, Rijksmuseum, LOC, Wikimedia Commons, Japan Search, NASA, Poly Haven). Some entries are
  reference-only or non-commercial (for example CC BY-NC, or the V&A's non-commercial terms). Check each asset's
  licence before you ship it.

If you install it anyway, set `OIL_NO_UPDATE_CHECK=1`. Do not give it a token unless you mean to use paid credits.

## Awwwards MCP (reference-only, optional)

[INSANE0777/Awwwards-mcp](https://github.com/INSANE0777/Awwwards-mcp), MIT, npm package `awwwards-mcp`. It is an
independent project, not affiliated with Awwwards. **Telar adds no `.mcp.json` or `mcpServers` entry.** It is optional:
install it yourself, pinned:

```bash
claude mcp add awwwards -- npx -y awwwards-mcp@1.18.0
```

- **Requires Node >= 22.13.**
- **The `npx` path covers the core tools only**: search, details, compare, briefs, collections, directory. The
  browser tools need a separate global install of `playwright` and `ffmpeg-static` plus a Chromium, as described in the
  upstream README ("Browser-enabled install"). These are the capture, analyze, motion, verify, component, token-export
  and 3D tools. `record_site_motion` also needs ffmpeg.
- **Use it for personal, non-commercial design inspiration**, as its README states. It scrapes public awwwards.com
  pages (1 request/second, robots.txt paths, cached 7 days in `~/.awwwards-mcp/`). Awwwards' screenshots and content
  belong to Awwwards and the credited creators. Do not bulk-scrape, redistribute or republish them, and do not copy a
  reference site's assets or code into a build.
- **The `capture_*`, `analyze_*`, `audit_url` and `verify_*` tools fetch any URL you give them.** Point them only at
  sites you are allowed to inspect. `capture_scene_3d` with `op: "download_assets"` downloads a page's assets. Use it
  only for assets you own or have a licence for.
- The server checks the npm registry once a day for a newer version (a stderr notice only). It self-updates only if
  you set `AWWWARDS_AUTO_UPDATE=1`. Leave that unset to keep the pin.

Main tools:

| Group | Tools |
|---|---|
| Inspiration (core) | `search_sites`, `get_site_details`, `compare_sites`, `create_design_brief`, `search_elements`, `get_collections`, `search_directory`, `get_annual_categories`, `get_index_status`, `get_index_stats` |
| Page evidence (browser) | `capture_live_site`, `analyze_page_structure`, `analyze_scroll_map`, `analyze_hover_census`, `record_site_motion`, `capture_component`, `export_design_tokens`, `analyze_images`, `capture_pose_3d`, `capture_scene_3d` |
| Audit and verify | `audit_url` (performance evidence), `analyze_accessibility` (evidence, not a WCAG verdict), `verify_build` (build-vs-reference score), `verify_flow` |

If it is installed, these agents use it as an optional input: `web-ui-ux-specialist` and `web-screen-builder` for reference sites, `astro-web-expert`
for marketing-site references, `web-performance-optimizer` for `audit_url` / `analyze_scroll_map`, and
`web-accessibility-expert` for quick `analyze_accessibility` evidence.
