# Third-party sources (provenance manifest)

Every piece of third-party material in Telar, how it got here, and exactly which upstream commit it came from.
Attribution and full license texts live in [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md); the user-facing
guide (what each item is for, install steps, warnings) is [`third-party/README.md`](README.md).

**Modes**

- **vendored**: a pinned copy shipped inside Telar. Upstream text is kept as is, except for the local modifications listed per row.
- **adapted**: upstream code or ideas rewritten for Telar. Telar owns the result; the upstream baseline is recorded.
- **reference-only**: nothing is copied. Telar documents the item, and users install it themselves if they want it.

## Manifest

| Name | Upstream URL | Mode | Pinned SHA | Pin date | License | Local paths | Local modifications |
|---|---|---|---|---|---|---|---|
| metaswarm | https://github.com/dsifry/metaswarm | adapted | baseline v0.11.0 / `c86fd6c` | 2026-06-26 | MIT | `skills/orchestration/external-tools/adapters/_common.sh`, `codex.sh`, `gemini.sh`; `scripts/estimate-cost.sh`; `scripts/tl-telar-fetch-pr-comments.ts` | Rewritten for Telar's dispatcher, budget ledger and config-driven routing. Reviewed against upstream v0.14.0 / `213d495df7e87b5be77f47ef895086fd9379033c` on 2026-11-09. No port needed. Upstream's role/model-resolution changes conflict with Telar's resolve-role routing, which Telar already covers. The severity-gated review-finding contract has been deferred as a possible future feature. |
| karpathy-guidelines | https://github.com/forrestchang/andrej-karpathy-skills | adapted | upstream HEAD `2c60614` | 2026-06-26 | MIT | `rules/simplicity-first.md` | One principle adapted and rewritten as a Telar rule. |
| dimensional-drawing | https://github.com/enesozturk/dimensional-drawing | vendored | `5c457437c8c83524308aad3b7443e81adcc13153` | 2026-11-09 | MIT | `skills/third-party/dimensional-drawing/` (`dimensional-drawing/`, `dimensional-drawing-motion/`, `LICENSE`) | Only the two skills under upstream `skills/` are copied; the 18 MB `assets/` media, README and repo files are not. Telar adapter frontmatter added to both `SKILL.md` files (`id`, `category`, `tags`, `capabilities`, `useWhen`, `provenance`); upstream `name`, `description` and body unchanged. Ids: `dd-dimensional-drawing`, `dd-dimensional-drawing-motion`. Adapter note added at the top of the motion skill (optional skill; Node + headless Chromium + ffmpeg). One declared path edit: in `adapters/headless/README.md` the `cd skills/dimensional-drawing-motion/adapters/headless` line now reads `cd <dimensional-drawing-motion skill folder>/adapters/headless`, so it is correct in the source tree and in the Codex package. |
| design.how | https://github.com/arla6ka/design.how | vendored | `419fa5af1721eebfab9e0062a630de36ffd0b342` | 2026-11-09 | MIT | `skills/third-party/design.how/` (`design-system-boss/`, `build-design-system/`, `token-mapping/`, `component-docs/`, `ui-review/`, `LICENSE`) | Only five workflow skills plus their `references/`, `playbooks/` and `scripts/` are copied; `systems/`, `vault/`, `evals/`, `assets/` and the README are not. **The `migrate-design-system` skill is not vendored (owner decision, 2026-11-09)**, nor its scripts; its `land.mjs` commits with no prompt and can run an arbitrary `sh -c` command from `--bodies-check` or `LAND_BODIES_CHECK`. Upstream mentions of `migrate-design-system` and `land.mjs` in the vendored bodies (`design-system-boss` incl. `playbooks/migrate.md`, `build-design-system` incl. `references/glossary.md`) are left as upstream text and are dangling on purpose. Telar adapter frontmatter added to all five `SKILL.md` files; upstream `name`, `description` and body unchanged. Ids carry a `dh-` prefix (`ui-review`, `component-docs` and `token-mapping` are generic names, and `design-system` is already a Telar command). An adapter note at the top of `design-system-boss` and `build-design-system` says migration is not shipped (Telar flow: `web-design-system-architect`, one owner-approved commit per surface), that Telar's git policy wins, and maps the `dh-` ids. Scripts are unchanged; see the review notes below. |
| brand-identity-skill | https://github.com/fatihaydost/brand-identity-skill | reference-only | `3ba008e57b9363cf2a9117303237f951a7c1ef00` (reviewed) | 2026-11-09 | MIT (ships its own `THIRD_PARTY_NOTICES.md`) | none (documented in `third-party/README.md`) | Not copied. Install via its plugin marketplace. |
| oil-ui | https://github.com/oil-oil/oil-ui | reference-only | `16b30579489155ed4fae723c4d031e9f4d3c36df` (reviewed) | 2026-11-09 | MIT | none (warning section in `third-party/README.md`) | Not copied and not routed to; users may install it at their own risk. Load-time update check, self-update, token reads, paid upsell. See the warning. |
| Awwwards MCP | https://github.com/INSANE0777/Awwwards-mcp (npm `awwwards-mcp` v1.18.0) | reference-only | `60fb5573d992bb40ea3d1070b936a78e28582eca` (reviewed) | 2026-11-09 | MIT | none (documented in `third-party/README.md`); no `.mcp.json` / `mcpServers` entry | Not copied. Pinned install command documented. |

## Vendored-file review notes (2026-11-09)

Every vendored file was read in full before it was copied. Nothing contains telemetry, self-update, downloads,
obfuscated code, upsells or prompt-injection text. The findings worth knowing:

- **design.how `capture.mjs`**: its route status preflight (`fetch`, ~L185) runs outside the write guard. An absolute or
  `//host` route in the operator's own surfaces file can reach a non-local host with a GET. The browser itself stays
  guarded. `--states` and `--eval` files run as code by design, and output folders can hold captured request bodies
  (keep them gitignored; the skill puts them under `.design-system/`).
- **design.how `capture-guard.mjs`**: blocks non-local hosts and every write by default. Its log stores non-GET request
  bodies, and WebSockets are not guarded.
- **design.how `find-chromium.mjs`**: runs only the fixed commands `git rev-parse --show-toplevel` and `npm root -g`. It
  launches whatever `PW_CHROMIUM` points to and loads Playwright from the project or global `node_modules`.
- **design.how `check-system.mjs`**: no network and no git writes. Every write needs an explicit flag; config-supplied
  allowlist/stock paths are not confined to the repo root.
- **design.how `oklch.mjs`, `pixdiff.mjs`**: local files only (pure color math; `.diff.png` files beside the input or in
  `--out`, or a temp folder they clean up).
- **dimensional-drawing**: `examples/*.html` and `adapters/headless/player.html` load the Arimo font from Google Fonts.
  `adapters/headless/package.json` has a `postinstall` that runs `playwright install chromium` (a network download, only
  if you run `npm install`), and an `example` script that writes to an upstream `assets/` folder Telar does not ship.
  `render.mjs` spawns ffmpeg and writes only the output path you pass.

## How to check for updates

For each row with a pinned SHA:

```bash
# 1. What is upstream at now?
git ls-remote https://github.com/<owner>/<repo> HEAD

# 2. If it differs from the pinned SHA, fetch both and diff only the paths Telar uses.
git clone --filter=blob:none https://github.com/<owner>/<repo> /tmp/<repo>-upstream
git -C /tmp/<repo>-upstream diff <pinned-sha> HEAD -- skills/<skill>/   # e.g. skills/ui-review/

# 3. Read every changed file in full (scripts especially) before re-vendoring: look for network
#    calls, credential reads, writes outside the project, load-time `!` shell hooks, self-update,
#    telemetry, upsells and instruction-override text. Never run anything from the clone.
# 4. Re-copy, re-apply the local modifications listed above, update this table (SHA + pin date)
#    and THIRD_PARTY_NOTICES.md, then run the validators and `node scripts/generate-codex-plugin.js`.
```

For reference-only rows, repeat steps 1–3 and update the warnings in `third-party/README.md` if behaviour changed.
For the npm-distributed Awwwards MCP, also check `npm view awwwards-mcp version` and bump the pinned
`awwwards-mcp@<version>` in the install command only after reviewing the release.
