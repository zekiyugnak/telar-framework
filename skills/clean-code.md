---
id: clean-code
category: skill
impact: HIGH
impactDescription: "Duplication, bloat, and the wrong abstraction are the defects that compound fastest across a codebase — this is the shared authoring contract that keeps every implementer at senior level and is enforced by the Maintainability reviewer."
tags: [clean-code, dry, solid, refactoring, reuse, code-smells, maintainability]
capabilities:
  - Reuse before creating — search shared locations first; never re-implement an existing unit
  - Apply DRY correctly — unify only code that changes together for the same reason (Metz test)
  - Avoid the wrong abstraction — prefer a little duplication over a premature shared abstraction
  - Enforce mechanical Clean Code — named constants, argument limits, no ambiguous null, command-query separation
  - Apply SOLID and flag Fowler code smells without dogmatic over-application
  - Use a design pattern only where it earns its complexity (never speculative)
useWhen:
  - Writing or reviewing any application code (components, hooks, utils, RPCs, views, services)
  - Deciding whether to extract shared code or leave duplication
  - A change touches something that may already exist elsewhere
  - The Maintainability reviewer flags a D-* finding and you need the remediation
---

# clean-code

## Problem

The defects that compound fastest are not crashes — they are **duplication**, **bloat**,
and the **wrong abstraction**. Copy-pasted logic drifts out of sync; speculative
flexibility slows every future change; and — the subtle one — a premature shared
abstraction that unifies code which only *looked* alike couples unrelated call sites,
and coupling is worse than duplication. Without one contract, each implementer applies
a different, often dogmatic, standard.

## Solution

Author against one contract, grounded in the literature: Fowler (*Refactoring*,
*YAGNI*), R. C. Martin (*Clean Code* + SOLID), Sandi Metz (*The Wrong Abstraction*),
GoF. The Maintainability reviewer enforces the same rules (rubric
`resources/rubrics/orchestration/maintainability-design-adversarial-rubric.md`).

### 1. Reuse before create

Before writing a unit (component/widget/hook/util/RPC/view/query), search the stack's
shared location and reuse what exists. Never re-implement an existing shared unit.

| Stack | Shared location |
|---|---|
| React Native | `src/components/common`, `src/hooks`, `src/lib` |
| Flutter | `lib/shared`, `lib/core` |
| Web (React/Next/TanStack) | `components/ui`, shared `features/*`, `lib/` |
| Astro (marketing/careers) | shared `src/components`, `src/layouts` |
| Supabase / Postgres | a database **view**, **RPC**, or SQL **function** |
| Rust service | a `services/` function or a shared module |
| Desktop (Electron/Tauri) | shared renderer components + a single typed IPC layer |

### 2. DRY, correctly — the Metz test

Apply DRY **only** to code that "changes together, at the same time, for the same
reason." That is the single discriminator:

- **Same reason to change → unify** (semantic duplication counts: two code paths doing
  the same job differently still duplicate).
- **Different responsibilities that merely look alike → leave duplicated.** Every shared
  abstraction couples its call sites; a wrong abstraction is worse than duplication.

**Wrong-abstraction remediation** (when a shared helper has decayed into a
parameter-and-conditional tangle): inline it back into each caller, keep the subset
that caller actually uses, delete the rest.

```ts
// WRONG ABSTRACTION — "shared" but every caller passes flags to carve out its slice
function priceFor(order, { isSubscription, isTrial, applyTax }) {
  let p = order.base
  if (isSubscription) p *= 0.9
  if (isTrial) p = 0
  if (applyTax) p *= 1.2          // grows a new branch per almost-fitting requirement
  return p
}

// REMEDIATION — re-inline; each site keeps only what it needs (Metz)
function subscriptionPrice(order) { return order.base * 0.9 * 1.2 }
function trialPrice() { return 0 }
// These do NOT change together for the same reason → they stay separate.
```

### 3. Mechanical Clean Code (the objectively-checkable rules)

- Replace magic numbers/strings with named constants; searchable, intention-revealing names; no Hungarian/type-prefixes.
- Prefer 0–2 arguments; no flag/boolean arguments (split the function); prefer return values over output (mutated) arguments.
- Command-Query Separation: a function either does something or answers something, not both.
- No ambiguous `null`/`undefined` return/pass in JS/TS/Dart — use a typed absent value or throw. (Rust `Option`/`Result` are idiomatic and correct — this does not apply.)
- Comments explain **why**, never restate the **what**.

### 4. SOLID & Fowler smells

- SRP (one reason to change), OCP, LSP (subtypes substitutable — a behavior-changing violation is a real defect), ISP, DIP.
- Watch for: long parameter list / data clumps → parameter object; feature envy; primitive obsession; divergent change / shotgun surgery; message chains / inappropriate intimacy (Law of Demeter).

### 5. Patterns earn their complexity

Use a GoF/idiomatic pattern only when the code clearly needs it. A factory, interface,
generic, or config with a single caller or a value that never varies is **speculative
generality** (YAGNI) — a defect, not good design. Simplicity-first is binding.

### 6. Do NOT over-apply (a dogmatic reviewer wrongly flags these)

- Refactoring, test-writing, or malleability work is **not** YAGNI (Fowler: YAGNI is about presumptive *features*).
- Do not force tiny-function extraction, hard function-length caps, or one-level-of-abstraction as gates (contested — Muratori). Advisory at most.
- Do not force-merge coincidental similarity into a shared abstraction.
