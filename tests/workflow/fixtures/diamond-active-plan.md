# Active Plan
<!-- status: in-progress -->

## Goal
Diamond DAG fixture: A -> {B, C} -> D, with B and C disjoint.

## Work Units

### WU-A: base module
- file_scope:
  - src/core/base.ts
- deps: []

### WU-B: feature b
- file_scope:
  - src/features/b.ts
- deps: [WU-A]

### WU-C: feature c
- file_scope:
  - src/features/c.ts
- deps: [WU-A]

### WU-D: integrate
- file_scope:
  - src/app.ts
- deps: [WU-B, WU-C]
