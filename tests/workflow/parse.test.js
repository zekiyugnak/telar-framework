#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const { parsePlan, parseState } = require('../../scripts/tl-telar-wu-scheduler');

const PLAN = `# Active Plan
<!-- status: in-progress -->

## Goal
Ship auth.

## Work Units

### WU-001: Add auth API
- spec: Add loginUser().
- dod:
  - [ ] returns token
- file_scope:
  - src/api/auth.ts
- deps: []
- checkpoint: false

### WU-002: Add login screen
- spec: Screen using loginUser().
- file_scope:
  - src/screens/LoginScreen.tsx
- deps: [WU-001]
- checkpoint: false

### WU-003: Add profile screen
- spec: Profile screen.
- file_scope:
  - src/screens/ProfileScreen.tsx
- deps: []
- checkpoint: false
`;

// parsePlan extracts id, deps, fileScope for every WU block
{
  const { wus, warnings } = parsePlan(PLAN);
  assert.equal(wus.length, 3);
  const byId = Object.fromEntries(wus.map((w) => [w.id, w]));
  assert.deepEqual(byId['WU-001'].deps, []);
  assert.deepEqual(byId['WU-001'].fileScope, ['src/api/auth.ts']);
  assert.deepEqual(byId['WU-002'].deps, ['WU-001']);
  assert.deepEqual(byId['WU-002'].fileScope, ['src/screens/LoginScreen.tsx']);
  assert.deepEqual(warnings, []);
}

// parsePlan flags two dep-unordered WUs that write the same path
{
  const plan = `## Work Units

### WU-001: A
- file_scope:
  - src/shared.ts
- deps: []

### WU-002: B
- file_scope:
  - src/shared.ts
- deps: []
`;
  const { warnings } = parsePlan(plan);
  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /WU-001.*WU-002.*src\/shared\.ts|src\/shared\.ts/);
}

// parsePlan does NOT flag two WUs that share a path when a dep edge orders them
// (buildReachability true-branch): a dep ordering makes the shared write
// deterministic, so it is a legitimate plan, not an ambiguous one.
{
  const plan = `## Work Units

### WU-001: base
- file_scope:
  - src/shared.ts
- deps: []

### WU-002: extends base
- file_scope:
  - src/shared.ts
- deps: [WU-001]
`;
  const { warnings } = parsePlan(plan);
  assert.deepEqual(warnings, []);
}

// ...and the ordering is direction-agnostic: the reverse dep edge is equally
// unambiguous (the reachability check walks the transitive dep graph either way).
{
  const plan = `## Work Units

### WU-001: extends base
- file_scope:
  - src/shared.ts
- deps: [WU-002]

### WU-002: base
- file_scope:
  - src/shared.ts
- deps: []
`;
  const { warnings } = parsePlan(plan);
  assert.deepEqual(warnings, []);
}

// parseState maps ids to statuses; absent WU is not in the map
{
  const state = `# Execution State

## Work Unit Status

| WU     | Status      | Phase     | Retries | Writer Model |
|--------|-------------|-----------|---------|--------------|
| WU-001 | COMPLETE    | COMMITTED | 0       | claude       |
| WU-002 | IN-PROGRESS | VALIDATE  | 1       | codex        |
`;
  const m = parseState(state);
  assert.equal(m.get('WU-001'), 'COMPLETE');
  assert.equal(m.get('WU-002'), 'IN-PROGRESS');
  assert.equal(m.has('WU-003'), false);
}

console.log('tl-telar-wu-scheduler parse: all tests passed');
