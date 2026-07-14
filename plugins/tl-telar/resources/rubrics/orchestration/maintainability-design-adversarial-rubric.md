# Maintainability & Design Adversarial Rubric

## Purpose

Consulted by Phase 3 of `skills/orchestration/orchestrated-execution/` for the
always-on **Maintainability** reviewer whenever any code file is in a Work Unit's
`file_scope`. Grounds senior-level design review in named sources (Fowler,
*Refactoring* & *YAGNI*; R. C. Martin, *Clean Code* + SOLID; Sandi Metz, *The Wrong
Abstraction*; GoF). It catches duplication, bloat, smells, and coupling defects, and —
unlike the pure-adversarial rubrics — MAY additionally surface reuse/refactor
suggestions as non-blocking advisories.

## Reviewer mode

**Adversarial + advisory.** `[BLOCKING]` rules → FAIL with a cited rule ID (same
binary gate as the generic rubric). `[ADVISORY]` rules → emit an `advisories[]` entry
(schema: `../../../skills/orchestration/plan-review-gate/references/verdict-schema.md`);
advisories NEVER set `verdict: FAIL` and NEVER block COMMIT. Fresh `Task()` instance;
sees only WU spec, DoD, file scope, and git diff. Runs on Opus.

**Binding guardrails (violating these makes the finding itself invalid):**
- Flag duplication as must-unify ONLY when the sites change together, at the same
  time, for the same reason (Metz). Coincidental similarity with different
  responsibilities → do NOT flag; forcing a shared abstraction is the wrong
  abstraction and is worse than duplication.
- Do NOT demand tiny-function extraction, hard function-length caps, or
  one-level-of-abstraction as gates (contested — Muratori). These are ADVISORY at most.
- Do NOT flag refactoring, test-writing, or malleability work as YAGNI (Fowler: YAGNI
  applies to presumptive *features* only).

## Evaluation criteria

### D-DUP — Duplication
- D-DUP1 [BLOCKING]. Textual copy-paste / near-duplicate block whose sites change together for the same reason (Metz test) → unify. FAIL.
- D-DUP2 [BLOCKING]. Semantic duplication — two code paths implementing the same job/behavior differently, same reason to change → unify. FAIL.
- D-DUP3 [ADVISORY]. Borderline similarity that may or may not share a reason to change → note as a candidate, do not block.

### D-REUSE — Reuse
- D-REUSE1 [BLOCKING]. An existing shared component/widget/hook/util/RPC/view/query was re-implemented instead of reused. FAIL.
- D-REUSE2 [ADVISORY]. A new single-responsibility unit clearly belongs in the stack's shared location but was inlined → suggest extraction.

### D-BLOAT — Over-engineering (cross-refs generic G9)
- D-BLOAT1 [BLOCKING]. Speculative abstraction: factory/interface/generic/config/props/params with a single caller or a value that never varies (YAGNI; Fowler speculative generality). FAIL.
- D-BLOAT2 [BLOCKING]. Dead flexibility: unused parameters, options, or branches introduced by this diff. FAIL.
- D-BLOAT3 [ADVISORY]. Code doing more than the WU's DoD needs → suggest trimming.

### D-SMELL — Fowler smells (intent-reading)
- D-SMELL1 [ADVISORY]. Long method / large class markedly beyond the surrounding file's norm (no hard line cap).
- D-SMELL2 [BLOCKING]. Long parameter list (>=4 unrelated params) or a repeated data clump → introduce a parameter object / typed struct. FAIL.
- D-SMELL3 [ADVISORY]. Feature envy — a function more interested in another module's data than its own.
- D-SMELL4 [ADVISORY]. Primitive obsession — bare primitives where a small named type/enum belongs.
- D-SMELL5 [ADVISORY]. Divergent change / shotgun surgery — one module changing for many reasons, or one change forcing edits across many modules.
- D-SMELL6 [ADVISORY]. Message chains / inappropriate intimacy — a chain of `.a().b().c()` or a module reaching into another's internals (Law of Demeter; distinct from generic G10 which stays BLOCKING for import cycles / boundary breaks).

### D-SOLID — SOLID
- D-SOLID1 [BLOCKING]. Liskov violation that changes behavior — a subtype not substitutable for its base. FAIL.
- D-SOLID2 [ADVISORY]. SRP / OCP / ISP / DIP violation (architectural judgment).

### D-PATTERN — Design patterns
- D-PATTERN1 [ADVISORY]. A fitting GoF/idiomatic pattern is clearly warranted but absent → suggest it (never demand). A speculative/unneeded pattern is D-BLOAT1, not this.
- D-PATTERN2 [BLOCKING]. A pattern is misapplied for the context and causes a defect (e.g., a singleton holding request-scoped state). FAIL.

### D-COHESION — Cohesion & coupling
- D-COHESION1 [ADVISORY]. Low cohesion / high coupling not already caught by generic G10.

### D-CLEAN — Mechanical Clean Code (objectively checkable)
- D-CLEAN1 [BLOCKING]. Magic number/string literal with domain meaning not extracted to a named constant; single-letter or unsearchable name in non-trivial scope; Hungarian/type-prefix encoding. FAIL.
- D-CLEAN2 [BLOCKING]. `null`/`undefined` returned or passed where a typed absent-value or exception fits (JS/TS/Dart). Rust `Option`/`Result` are idiomatic → NOT a violation. FAIL (non-Rust only).
- D-CLEAN3 [BLOCKING]. Function with >=3 arguments, a flag/boolean argument, or an output (mutated) argument, where a split or return value is idiomatic. FAIL.
- D-CLEAN4 [BLOCKING]. Command-Query Separation violation — a function both mutates state and returns a value used as a query. FAIL.
- D-CLEAN5 [ADVISORY]. Intention-revealing naming / one-word-per-concept consistency (judgment).

## Verdict format

Reviewer returns a single JSON object matching the verdict schema
(`skills/orchestration/plan-review-gate/references/verdict-schema.md`) with
`reviewer: "maintainability"`. `blockers[]` cite `[BLOCKING]` rule IDs; `advisories[]`
cite `[ADVISORY]` rule IDs. `verdict: "PASS"` iff `blockers` is empty (advisories do
not affect the verdict).
