---
id: web-e2e-catalog
category: skill
impact: MEDIUM
impactDescription: "Structures E2E scenarios as a versioned catalog (matrix + per-scenario docs + smoke/basic/full tags) with a phased regression orchestrator, so suites stay discoverable and runnable at the right granularity"
tags: [testing, e2e, playwright, catalog, ci, web]
capabilities:
  - Catalog INDEX matrix with per-scenario markdown docs
  - Tag taxonomy (@smoke / @basic / @full) mapped to npm scripts
  - Phased regression orchestrator (unit -> pgTAP -> per-surface E2E -> cross-surface)
  - Multi-baseURL Playwright config (dual webServers, workers:1)
useWhen:
  - Organizing a growing E2E suite so scenarios stay discoverable
  - Wiring a regression command that runs the pyramid in order
---

# Structure a Growing E2E Suite as a Versioned Catalog, Not a Pile of Specs

The most common failure mode for an E2E suite that starts small and grows is that it never gets a map: nobody can tell what's covered without reading every spec file, there's no way to run just the fast subset before a merge, and there's no declared order between the layers that make up the full pyramid (unit, DB, per-surface E2E, cross-surface E2E). This skill covers the pattern that avoids that: a catalog `INDEX.md` that tracks each scenario's id/title/surfaces/status before it's even automated, a `@smoke`/`@basic`/`@full` tag taxonomy mapped to npm scripts, a phased regression orchestrator that runs the pyramid in a fixed, fail-fast order, and the multi-baseURL Playwright config that makes cross-surface scenarios possible in the first place.

## Problem

```markdown
<!-- BAD: specs/ is a flat pile, no map of coverage, no way to run "just the fast ones" -->
src/e2e/specs/
  test1.spec.ts
  signup_flow.spec.ts
  admin-stuff.spec.ts
  reveal-thing-v2.spec.ts
<!-- nobody knows which of these are safe to skip before a merge, or what "done" means -->
```

```json
// BAD: one undifferentiated script — every run is the slow, full run
{
  "scripts": {
    "test:e2e": "playwright test"
  }
}
```

```bash
# BAD: no declared order between layers — a broken unit test surfaces only after
# a 10-minute Playwright run against a live DB has already spun up and torn down
pnpm test:e2e
```

## Solution

### (a) Catalog matrix: `catalog/INDEX.md`

Every scenario is defined human-readably in the catalog *before* it's automated as `scenarios/<id>-*.spec.ts`. The index tracks id, title, surfaces, and status (`taslak` draft / `otomatik` has-a-spec / `geçiyor` green), so the suite's coverage is legible from one file instead of requiring a read-through of every spec:

```markdown
| id | başlık | surface'ler | durum |
|----|--------|-------------|-------|
| S01 | Aday finalize → credential onayı → reveal | client-web + admin | geçiyor |
| S02 | Cross-region corridor kapalı (TPC01) → reveal engellenir | client-web | geçiyor |
| S03 | contact_reveals kotası tükenmiş (TPC02) → reveal diyaloğu açılmaz | client-web | geçiyor |
| S04 | Aday credential submit → admin credential RED (reject) yolu — reason-gate + reject persist | admin | geçiyor |
| S06 | Employer→candidate cross-surface mesajlaşma — gerçek UI ile çift-yönlü thread | client-web | geçiyor |
| S07 | Employer abonelik talebi → admin grant (RPC) → kota yansıması | client-web + admin-RPC | geçiyor |

Durum: **taslak** (yalnız katalog) · **otomatik** (spec var) · **geçiyor** (yeşil koşuyor)
```

> The matrix above is a verbatim example from the reference project, so its column headers and status enum are in that project's language (`taslak`/`otomatik`/`geçiyor`). For a new suite, use whatever labels fit your project — the English equivalents are **draft** (catalog only) / **has-spec** (automated) / **green** (passing). Only the three-state progression matters, not the words.

Each row gets a matching per-scenario markdown doc (e.g. `catalog/S01.md`) once it moves past `draft` (`taslak`), describing the arrange/act/assert shape in prose before or alongside the spec file — the catalog is the source of truth for "what should exist," the spec files are "what does exist."

### (b) Tag taxonomy → npm scripts

Tags on each `test()` map directly to `package.json` scripts, so any granularity — from a pre-commit smoke check to the full regression tier — is one command away:

```json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:smoke": "playwright test --grep @smoke",
    "test:e2e:basic": "playwright test --grep @basic",
    "test:e2e:full": "playwright test --grep @full",
    "test:e2e:regression": "playwright test --grep \"@smoke|@basic|@full\"",
    "test:e2e:ui": "playwright test --ui"
  }
}
```

`@smoke` scenarios should be the handful that would block every merge if broken; `@basic` covers common-path coverage; `@full` is everything else, including edge cases and cross-surface scenarios like S01. `test:e2e:regression` is a grep union of all three tiers, not a fourth tag — there's exactly one taxonomy to keep in sync with the catalog.

### (c) Phased regression orchestrator

`scripts/regression.sh` runs the full pyramid in 4 gated phases, fail-fast on the first red phase, so a broken unit test never gets masked by (or has to wait behind) a slow live-DB E2E run:

```bash
# Phases (in order):
#   0. unit         — vitest across surfaces (admin, client-web, web). No stack needed.
#   1. pgtap        — Postgres unit tests (`supabase test db`). Needs the local Supabase stack up.
#   2. surface-e2e  — per-surface Playwright suites (admin, client-web, web), each run against
#                     the SHARED seed-e2e fixture (21 users). Auto-skips (non-fatal) if fixture absent.
#   3. tp-e2e       — @tp/e2e scenario suite, tiers @smoke + @basic + @full (`test:e2e:regression`).
#                     Self-contained/namespace-isolated, no reset needed.
run_phase3_tp_e2e() {
  banner 3 "@tp/e2e scenarios (@smoke + @basic + @full)"
  pnpm --filter @tp/e2e test:e2e:regression || fail_phase 3 "tp-e2e"
}
```

Phase 0 and 1 need no browser and catch the cheapest bugs first; phase 2 exercises each surface in isolation against a shared seed fixture; phase 3 is the cross-surface scenario tier (catalog + tags from (a)/(b) above) — the only phase that can prove a flow like S01's admin-then-client-web handoff actually works end to end.

### Multi-baseURL Playwright config

Phase 3's cross-surface scenarios need more than one `baseURL` in flight, which `playwright.config.ts` provides via two `projects` and two `webServer` entries that Playwright boots and tears down itself:

```typescript
import { defineConfig } from "@playwright/test";
import { CLIENT_WEB_URL, ADMIN_URL } from "./env";

export default defineConfig({
  testDir: "./scenarios",
  timeout: 90_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,   // paylaşımlı canlı DB; namespace izole ama admin karar yarışına karşı seri
  workers: 1,
  reporter: [["list"], ["html", { open: "never" }]],
  use: { trace: "retain-on-failure", screenshot: "only-on-failure" },
  projects: [
    { name: "client-web", use: { baseURL: CLIENT_WEB_URL } },
    { name: "admin", use: { baseURL: ADMIN_URL } },
  ],
  webServer: [
    {
      command: "pnpm --filter @talent-portal/client-web build && pnpm --filter @talent-portal/client-web preview --port 4173 --strictPort",
      url: CLIENT_WEB_URL,
      reuseExistingServer: !process.env.CI,
      timeout: 180_000,
    },
    {
      command: "pnpm --filter @talent-portal/admin build && pnpm --filter @talent-portal/admin preview --port 4183 --strictPort",
      url: `${ADMIN_URL}/expat/login`,
      reuseExistingServer: !process.env.CI,
      timeout: 180_000,
    },
  ],
});
```

A single scenario that needs both surfaces (e.g. S01: admin verifies a credential, then client-web performs the reveal) opens its own `browser.newContext({ baseURL })` per surface rather than relying on the project's single `use.baseURL`, and skips itself under the project it doesn't own:

```typescript
test("S01: aday finalize → credential onayı → reveal @client-web", { tag: "@full" }, async ({ browser }) => {
  test.skip(test.info().project.name !== "client-web", "S01 tek koşum (kendi context'lerini açar)");
  // ... arrange, then act-1 against an admin newContext({ baseURL: ADMIN_URL }),
  // act-2 against a client-web newContext({ baseURL: CLIENT_WEB_URL }) ...
});
```

## Why This Works

- **The catalog is legible before any code exists.** A `taslak` row in `INDEX.md` documents intended coverage even before a spec file is written, so "what's covered" is answerable by reading one table instead of grepping every `.spec.ts` for `test(`.
- **Tags decouple "what scenario is this" from "when do I run it."** A scenario keeps a single tag driving multiple entry points (`test:e2e:smoke`, `...:regression`, ad hoc `--grep`), so adding a fast pre-merge gate later never requires re-authoring scenarios, only adding a script that greps the tags that already exist.
- **The phased orchestrator fails fast at the cheapest layer.** Ordering unit → pgTAP → per-surface E2E → cross-surface E2E means a broken assertion in a pure function is caught in milliseconds, not after a multi-minute Supabase-stack boot and Playwright browser run has already happened.
- **`workers: 1` + `fullyParallel: false` is a correctness choice, not a speed default.** Two `projects` sharing one live DB are namespace-isolated per scenario (via `runId`), but admin-decision races (e.g. two workers processing the same queue) are a timing hazard the tags/catalog structure doesn't fix — serializing removes it deterministically.
- **Dual `webServer` entries make cross-surface scenarios possible in the first place.** Without a `baseURL` per project and a `newContext({ baseURL })` escape hatch, a scenario that spans admin and client-web would need two separate Playwright invocations glued together outside the test, losing the single-test-single-assertion-chain shape S01 relies on.

## Edge Cases & Pitfalls

### Common Mistakes

- **Conflating the CI workflow's per-surface suites with the regression orchestrator's cross-surface tier**: a repo's `e2e.yml` CI workflow typically runs the admin and client-web Playwright suites *per surface* (each surface's own `test:e2e` script) — it is not the same thing as the catalog's cross-surface `@tp/e2e` package, which runs through the regression orchestrator's Phase 3 (`test:e2e:regression`). A scenario like S01 that spans both surfaces only runs under Phase 3, never under the per-surface CI suites — don't assume CI green implies the cross-surface catalog passed, and don't assume `regression.sh` Phase 3 is redundant with CI.
- **Treating `workers: 1` as a perf knob to "optimize away"**: it is a shared-live-DB race-safety choice (see Why This Works above), not a default left over from a slow first pass. Raising worker count without first removing the shared-DB admin-decision race reintroduces flake, not speed.
- **Letting the catalog drift from the specs**: a scenario stuck at `taslak` for months while an actual spec exists for it (or vice versa) makes the matrix lie. Update the `durum` column in the same PR that adds or changes the spec.
- **Adding a scenario without a tag**: an untagged `test()` is invisible to every tiered script (`smoke`/`basic`/`full`/`regression`) and only runs under the untargeted `test:e2e` — silently dropping it from CI gates that grep by tag.
- **Skipping Phase 0/1 "to save time" locally**: running only Phase 3 hides the cheapest, fastest signal (unit + pgTAP) behind the slowest one, inverting the entire point of a fail-fast phase order.

## Verification

```bash
# Fast gate: the @smoke tier only
pnpm --filter @tp/e2e test:e2e:smoke

# Full tier before merge / release: the complete regression pyramid, phase by phase
./scripts/regression.sh
# or, to run just the tagged scenario tier directly:
pnpm --filter @tp/e2e test:e2e:regression
```

- [ ] Every scenario in `catalog/INDEX.md` has a `durum` that matches reality (`taslak`/`otomatik`/`geçiyor`).
- [ ] Every `test()` carries exactly one of `@smoke` / `@basic` / `@full`.
- [ ] `test:e2e:regression` is a grep union of the three tags, not a separately maintained list.
- [ ] `regression.sh` (or equivalent) fails fast on the first red phase — unit before pgTAP before per-surface E2E before cross-surface E2E.
- [ ] A cross-surface scenario opens its own `browser.newContext({ baseURL })` per surface and `test.skip`s itself outside its owning project.
- [ ] `workers: 1` / `fullyParallel: false` stays set as long as scenarios share a live DB with admin-decision races — don't raise it as a "perf fix" without first removing that race.

## References

- `docs/superpowers/references/2026-07-14-talent-portal-e2e-patterns.md` — sections 6 (catalog + tags + orchestrator) and 7 (multi-baseURL Playwright config), the harvested reference this skill is distilled from.
- Real source: `talent-portal/src/e2e/playwright.config.ts` (multi-baseURL config), `talent-portal/src/e2e/catalog/INDEX.md` (catalog matrix), `talent-portal/scripts/regression.sh` (phased orchestrator).
