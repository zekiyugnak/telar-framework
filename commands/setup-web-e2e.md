---
id: setup-web-e2e
name: Setup Web E2E Testing
description: Scaffold a Supabase/Playwright E2E harness for a Refine/TanStack web app using Telar's Arrange/Act patterns
category: command
usage: /tl-telar:setup-web-e2e [app-path]
example: /tl-telar:setup-web-e2e src/admin
phases:
  - name: Detect stack
    progress: 0-20%
  - name: Scaffold factory + config
    progress: 20-50%
  - name: Generate first scenario
    progress: 50-80%
  - name: Wire CI + review
    progress: 80-100%
---

# Setup Web E2E Testing

Scaffold a Supabase/Playwright E2E harness for a Refine or TanStack Router web app, using Telar's Arrange/Act test-data pattern instead of Supawright or ad hoc fixtures.

## Phase 1: Detect stack (0-20%)

### Load Agents
```yaml
agents:
  - web-e2e-testing-expert
```

### Resolve target app path
- Use `[app-path]` from the command argument if given (e.g. `src/admin`).
- If omitted, scan the repo for candidate web app roots (`src/admin`, `src/client-web`, `apps/web`, etc.) and confirm with the user before proceeding.

### Stack detection
Delegate stack identification to the `web-e2e-testing-expert` agent, which distinguishes:

- **Refine** — a `resources` array (in `<Refine resources={...}>` or a config module) mapping `name` to `list`/`create`/`edit`/`show` routes, plus `dataProvider`/`authProvider` wiring. Test targets are the CRUD routes Refine derives from each resource.
- **TanStack Router** — a file-based `routes/` tree (or a generated `routeTree.gen.ts`). Test targets are the leaf routes; loaders tell you what data a scenario needs arranged before navigation.
- **Astro** — marketing/content surface, out of scope for this harness; hand off to `astro-web-expert` if E2E is requested there instead.

A single app may mix Refine (e.g. an admin panel) and TanStack Router (e.g. a client-facing surface) — detect both independently rather than assuming one framework for the whole repo. This matters for Phase 2's multi-baseURL config and any later cross-surface scenario.

### Output
- Target app path confirmed
- Framework(s) identified per surface (Refine / TanStack Router / mixed)
- Enumerated test targets (routes/resources) for the first scenario in Phase 3

## Phase 2: Scaffold factory + config (20-50%)

### Load Skills
```yaml
skills:
  - supabase-e2e-harness
  - web-e2e-catalog
```

### Plain-fetch Supabase factory
Per `supabase-e2e-harness`, scaffold `factory/supabase.ts` (and sibling `factory/admin.ts`) as a plain-`fetch` client against `/auth/v1` and `/rest/v1` — **no `@supabase/supabase-js`** inside the Playwright process, to avoid its module-transform issues under Playwright's Node/ESM runner. Keep the anon-vs-service_role header split explicit:

- `headers()` — anon `apikey` + the actor's own bearer token. RLS evaluates as that user.
- `adminHeaders()` — `service_role` key as both `apikey` and bearer. Arrange only, never act.

Enforce the Arrange/Act rule from the start: **Arrange** (users, RBAC, entitlements) goes through `service_role` via the factory; **Act** (the behavior under assertion) always runs through real UI + anon key + the actor's own JWT, so RLS actually executes. Never let `service_role` perform the act.

Scaffold `runId` namespacing (`newRunId()`, `scopedEmail()`) so every arranged row is tagged with a run-unique id — this replaces teardown entirely; do not add an `afterEach` cleanup step in its place.

### Multi-baseURL Playwright config
Per `web-e2e-catalog`, scaffold `playwright.config.ts` with:

- Two (or more) `projects`, each with its own `baseURL`, when the app spans multiple surfaces (e.g. `admin` + `client-web`).
- Matching `webServer` entries per surface, so Playwright boots and tears down each server itself.
- `workers: 1` and `fullyParallel: false` — this is a correctness choice for suites sharing a live/CI Supabase instance (cross-scenario timing races on shared aggregate state), not a perf default to "optimize away."

### Output
- `factory/supabase.ts` + `factory/admin.ts` scaffolded (plain-fetch, no supabase-js)
- `playwright.config.ts` scaffolded with multi-baseURL projects/webServers, `workers: 1`
- Role factories stubbed for the app's actor types (e.g. candidate, employer, staff)

## Phase 3: Generate first scenario (50-80%)

### Load Skills
```yaml
skills:
  - web-e2e-locators
```

### Author the first smoke scenario
Using the test targets enumerated in Phase 1, write one `@smoke`-tagged scenario that exercises the harness end to end (arrange via `service_role`, act via real UI/login form). Apply `web-e2e-locators` locator discipline:

- `data-testid` as the primary locator for domain-dense rows/actions (parameterized by real record id).
- `getByRole`/`getByLabel` for generic controls (login forms, single-instance buttons).
- No fixed sleeps (`waitForTimeout`) — rely on Playwright's web-first auto-retrying assertions to absorb TanStack Query settling.
- shadcn/Radix combobox/dialog/toast recipes for portal-based components.

Add the scenario's entry to the catalog's `INDEX.md` matrix (per `web-e2e-catalog`) with its `@smoke`/`@basic`/`@full` tag, so it's discoverable before it's the only thing anyone remembers to grep for.

### Optional: official Playwright agents or MCP for live verification
- `npx playwright init-agents --loop=claude` (requires Playwright 1.56+) wires the Planner/Generator/Healer loop for scaffolding and evolving the durable, checked-in suite.
- Playwright MCP can verify a locator resolves or a flow navigates correctly against a running dev server before committing it to the suite — treat this as verification, not a substitute for the checked-in spec.

### Output
- First `@smoke` scenario authored and passing locally
- Catalog `INDEX.md` entry added with correct tag
- Locators verified against the live component tree (via MCP or manual run)

## Phase 4: Wire CI + review (80-100%)

### Load Skills
```yaml
skills:
  - web-e2e-review
```

### Ephemeral Supabase in CI
Wire the CI job to run against a fresh, ephemeral local Supabase stack, never a shared persistent CI database:

```bash
supabase start
supabase db reset
./scripts/seed-e2e.sh   # or the app's equivalent seed script
pnpm test:e2e:regression
supabase stop
```

### Run the review gate
Before declaring the harness done, run `web-e2e-review` against the new scenario(s). Treat any P0 finding (missing `await` on `expect`, swallowed errors, `service_role` used in an act, tautological or missing assertions) as a blocker, not a note — a green suite proves nothing if it silently always passes.

```bash
# P0 checks (see web-e2e-review for the full 24-pattern taxonomy)
grep -rn "expect(" tests/ e2e/ | grep -v "await expect("
grep -rln "SUPABASE_SERVICE_KEY\|service_role" tests/ e2e/ --include="*.spec.ts" | grep -v "factory/"
grep -rn "waitForTimeout" tests/ e2e/
```

### Note on git policy
This command scaffolds files only — it does **not** run `git add`/`git commit`/`git push`. Honor the user's git policy: always ask before committing or pushing, per the user's global instructions.

### Output
- CI workflow wired with ephemeral Supabase (start → db reset → seed → run → stop)
- `web-e2e-review` run against every new/changed spec, zero P0 findings outstanding
- Harness ready for the user to review and commit on their own terms

## Completion Checklist

- [ ] Target app path and framework(s) detected (Refine / TanStack Router / mixed)
- [ ] Plain-fetch Supabase factory scaffolded (no `@supabase/supabase-js`, no Supawright)
- [ ] Multi-baseURL `playwright.config.ts` scaffolded (`workers: 1`, dual webServers where applicable)
- [ ] First `@smoke` scenario authored using `data-testid`/`getByRole` locators, zero fixed sleeps
- [ ] Catalog `INDEX.md` entry added for the new scenario
- [ ] CI wired with ephemeral Supabase (start/db reset/seed/run/stop)
- [ ] `web-e2e-review` run with zero outstanding P0 findings
- [ ] No files committed or pushed — left for the user to review
