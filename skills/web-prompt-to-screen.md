---
id: web-prompt-to-screen
category: skill
impact: MEDIUM
impactDescription: Converts vague feature requests or Figma frames into precise, buildable web route specs (path, layout, component tree, data deps, states, i18n, a11y), reducing ambiguity and rework
tags: [screen-spec, route-spec, requirements, layout, tanstack-router, astro, nextjs, data-dependencies, i18n, rtl, a11y, figma]
capabilities:
  - Transform rough web feature descriptions into structured route specs (Mod A)
  - Read Figma designs via Figma MCP and convert to a web route spec (Mod B)
  - Hybrid mode combining REQUIREMENTS.md and Figma (Mod C)
  - Consult the Design Assets table in REQUIREMENTS.md to auto-select mode
  - Define route path, layout hierarchy, and component tree
  - Specify data dependencies (TanStack Query / Supabase), state ownership, and all four states
  - Enumerate i18n message keys and accessibility notes for the route
useWhen:
  - Building a web route that is listed in REQUIREMENTS.md
  - A stakeholder describes a page in plain language and you need a buildable spec
  - Planning routes before starting component development
  - Translating a Figma frame into a developer-ready web route specification
---

# Web Prompt to Screen

Converts screen/page descriptions and/or Figma designs into detailed, structured **web route specifications** for a Vite + React + TanStack (or Astro / Next.js) app. When REQUIREMENTS.md exists, always consult the Design Assets table first to determine which mode to use. This is the web parity of `prompt-to-screen`.

## Three Modes

| Mode | When to Use |
|------|------------|
| **Mod A — From description** | No Figma design available; build the spec from requirements text |
| **Mod B — From Figma** | A Figma design exists and its status is Final (or an accepted draft) |
| **Mod C — Hybrid** | Both a REQUIREMENTS.md spec and a Figma design exist; cross-reference and flag differences |

---

## Figma Decision Flow (when REQUIREMENTS.md exists)

Before producing a spec, check the Design Assets table in REQUIREMENTS.md:

```text
For route/screen UI-x:

├── Figma reference present AND status = "Final"
│     → Use Mod B automatically (no need to ask)
│
├── Figma reference present AND status ≠ "Final" (Draft, WIP)
│     → Ask user:
│       "UI-x has a Figma design but it is not finalised (status: [Draft/WIP])."
│       Options:
│         A) "I will finalise the design first" → skip this route for now
│         B) "Build from requirements text"     → Mod A
│         C) "Use the draft design as-is"        → Mod B (note: WIP)
│
├── Figma reference = "—" or "No design"
│     → Ask user:
│       "UI-x has no Figma design listed."
│       Options:
│         A) "I will create a design"        → skip this route for now
│         B) "Build from requirements text"  → Mod A
│
└── Route not in Design Assets table at all
      → Ask user:
        "UI-x is not in the Design Assets table. No requirements and no design exist for it."
        Options:
          A) "Add it to REQUIREMENTS.md first" → pause, update requirements
          B) "Describe it now"                 → Mod A (treat description as requirements)
```

**Rule:** Only "Final" status triggers automatic Mod B. All other situations require user confirmation.

---

## Mod A — From Description

### Input Analysis

Extract from the description or the REQUIREMENTS.md UI-x section:

```typescript
interface RoutePromptAnalysis {
  rawDescription: string
  purpose: string
  routePath: string            // e.g. "/candidates/$candidateId"
  primaryAction: string        // the one thing the user is here to do
  dataRequirements: string[]   // tables/queries/RPCs the route reads or writes
  interactions: string[]       // filters, mutations, bulk actions, navigation
  authContext: 'public' | 'authenticated' | 'role-gated'
  navigationContext: { from: string[]; to: string[] }
}
```

### Web Route Specification Template

```markdown
# Route: [Route Name] (UI-x)

## Requirements Reference
**REQUIREMENTS.md:** UI-x, F-y, F-z
**Figma:** [link or "None"]

## Purpose
[One sentence — what the user accomplishes here]

## Routing
- **Substrate:** TanStack Router file route | Astro page | Next App Router route
- **Route path / file:** `/_authenticated/candidates/$candidateId` (`src/routes/_authenticated.candidates.$candidateId.tsx`)
- **Auth:** public | authenticated (session guard in pathless/segment layout) | role-gated (RLS-backed; client hide is UX-only)
- **Search params:** `?tab=activity&page=2` (typed, validated)
- **Deep-linkable / bookmarkable:** yes/no

## Layout Hierarchy
​```
RouteRoot
  +-- PageHeader
  |     +-- Breadcrumb
  |     +-- Title: "[Name]"
  |     +-- PrimaryAction: Button "[Action]"
  +-- Content (grid / flex)
  |     +-- Region: [Primary]   -> loader-owned data
  |     +-- Region: [Secondary] -> component-owned (deferred) data
  +-- Footer / Pagination (if applicable)
​```

## Component Tree
| Component | Source | Props | State ownership |
|-----------|--------|-------|-----------------|
| CandidatesTable | reuse (features/candidates) | rows, pagination, sorting | local (table state) |
| StatusBadge | scaffold | tone, label | none (presentational) |
| InviteCandidateDialog | shadcn Dialog + form | open, onSubmit | local + mutation |

## Data Dependencies
- **Primary (loader-owned):** `candidatesPageQueryOptions(pagination, sorting)` → Supabase `select` (RLS-filtered), `count: 'exact'`
- **Deferred (component-owned):** `candidateActivityQueryOptions(id)` opened in a side panel — `useQuery`, not the loader
- **Mutations:** `inviteCandidate` → Supabase insert; on success `invalidateQueries(['candidates'])`

## State Ownership
- **Local:** table pagination/sorting, dialog open, form values (react-hook-form + zod)
- **Server (TanStack Query):** candidate list, candidate detail, activity
- **Global / URL:** active tab and page in search params; auth/session in router context

## States (all four required)
- **Loading:** skeleton mirroring the table/grid layout (no spinner-only, no CLS)
- **Empty:** icon + one-line explanation + primary CTA
- **Error:** plain-language message + retry action (never a raw stack trace)
- **Success:** the primary content

## i18n Keys
| Key | Default (en) | Notes |
|-----|--------------|-------|
| `candidates.title` | "Candidates" | page heading |
| `candidates.empty.title` | "No candidates yet" | empty state |
| `candidates.invite.cta` | "Invite candidate" | primary action |
| `candidates.error.retry` | "Try again" | error retry |
> Every key must exist in all locale catalogs (e.g. en.json + tr.json) before merge.

## Accessibility Notes
- Landmark: wrap content in `<section aria-labelledby="…-heading">` with an `<h1>`
- Focus: move focus to the page heading on route change; to the dialog on open, restore on close
- Names: icon-only actions get `aria-label`; table has an accessible caption/label
- Direction: all spacing/alignment uses logical properties (RTL-ready)
- Color: status never by hue alone — pair with icon/text; verify AA contrast

## Navigation
- **Entry points:** [where the user arrives from]
- **Exit points:** [where the user goes]
- **Route guard:** [redirect target if unauthenticated / unauthorized]
```

---

## Mod B — From Figma

Requires the Figma MCP to be connected.

### Steps

1. **Get the Figma node ID** from the Design Assets table in REQUIREMENTS.md.
2. **Fetch design context** via Figma MCP: `get_design_context(nodeId)`.
3. **Extract layout**: read the frame/auto-layout tree; map frames to the Layout Hierarchy and Component Tree.
4. **Infer responsiveness**: note which frames are container-driven vs viewport-driven; record breakpoint/container behavior.
5. **Map to the route spec template**: translate layers into components; mark which are reusable vs to-scaffold.
6. **Cross-reference requirements**: confirm the design covers every F-x for this route; flag any gaps.

### Output additions for Mod B

```markdown
## Figma Source
**Node ID:** [id]
**Last fetched:** [date]
**Design status:** Final | Draft | WIP

## Figma ↔ Requirements Discrepancies
| Requirement | In Figma? | Notes |
|-------------|-----------|-------|
| F-7 bulk-archive action | ❌ Missing | Figma v3 omits it — build from spec |
| F-3 empty state         | ✅ Present | Illustration + CTA provided |
```

---

## Mod C — Hybrid

Use when both a REQUIREMENTS.md spec and a Figma design exist:

1. Run Mod A (extract the spec from REQUIREMENTS.md).
2. Run Mod B (extract the spec from Figma).
3. Merge: use Figma for layout/visual and responsive intent; use REQUIREMENTS.md for business rules, data dependencies, auth context, and states.
4. Produce one unified route spec with a Figma ↔ Requirements Discrepancies section.

---

## Substrate Selection Guide

```typescript
// Pick the routing substrate from the app that already exists — never add a second router.
const substrate = {
  tanstackRouter: 'Vite + React 19 SPA / admin panel — file route + loader + TanStack Query',
  astro: 'Marketing / SEO / content route — static/SSR page, interactive islands only',
  nextApp: 'Authenticated Next.js console — Server Component fetch + client islands, segment auth guard',
}
```

---

## Verification

1. The Design Assets table in REQUIREMENTS.md was consulted before selecting a mode.
2. Mode selection followed the Figma Decision Flow (user confirmed for any non-Final design).
3. The route path and substrate are stated and match the app's existing router.
4. Every node in the layout hierarchy maps to a row in the Component Tree.
5. Data dependencies distinguish loader-owned (primary) from component-owned (deferred) data.
6. All four states are specified: loading, empty, error, success.
7. Every user-facing string has an i18n key present in the catalog plan.
8. Accessibility notes cover landmark/heading, focus management, accessible names, direction, and color.
9. In Mod B/C: a Figma ↔ Requirements Discrepancies section is present.

## References

- Input: `REQUIREMENTS.md` Design Assets table, Figma MCP (`get_design_context`)
- Used by: `agents/web-screen-builder.md`
- Related skills: `web-component-scaffolding`, `shadcn-component-patterns`, `tanstack-router-patterns`, `tanstack-query-patterns`, `supabase-rls-client-patterns`
- TanStack Router: https://tanstack.com/router/latest/docs/framework/react/guide/data-loading
- Astro routing: https://docs.astro.build/en/core-concepts/routing/
- Next.js App Router: https://nextjs.org/docs/app/building-your-application/routing
- WCAG 2.2: https://www.w3.org/TR/WCAG22/
</content>
