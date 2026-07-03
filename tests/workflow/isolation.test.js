#!/usr/bin/env node
'use strict';

// Worktree-isolation mode: computeReadiness({ isolateFileScope: true }) relaxes
// ONLY the disjoint-file-scope gate. deps, concurrency cap, critical-path order,
// and cycle detection stay identical. parsePlan(..., true) suppresses the
// ambiguous-plan (shared-file) warning. Default (flag absent/false) is byte-for-
// byte the pre-isolation behavior — covered by readiness.test.js / parse.test.js.

const assert = require('node:assert/strict');
const { computeReadiness, parsePlan } = require('../../scripts/tl-telar-wu-scheduler');

const statuses = (obj) => (id) => obj[id] || 'PENDING';
const wu = (id, deps, fileScope) => ({ id, deps, fileScope });

// overlapping PENDING scopes: BOTH admitted under isolation
// (contrast readiness.test.js "internal disjointness" -> only one admitted)
{
  const wus = [wu('WU-001', [], ['shared.ts']), wu('WU-002', [], ['shared.ts'])];
  const r = computeReadiness({ wus, statusOf: statuses({}), maxParallel: 3, isolateFileScope: true });
  assert.deepEqual(r.ready.sort(), ['WU-001', 'WU-002']);
  assert.deepEqual(Object.keys(r.blocked), []);
}

// overlap vs a RUNNING WU: admitted under isolation
// (contrast readiness.test.js file_conflict block)
{
  const wus = [wu('WU-001', [], ['shared.ts']), wu('WU-002', [], ['shared.ts'])];
  const r = computeReadiness({ wus, statusOf: statuses({ 'WU-001': 'IN-PROGRESS' }), maxParallel: 3, isolateFileScope: true });
  assert.deepEqual(r.ready, ['WU-002']);
  assert.deepEqual(r.running, ['WU-001']);
  assert.equal(r.blocked['WU-002'], undefined);
}

// deps STILL gate under isolation
{
  const wus = [wu('WU-001', [], ['a.ts']), wu('WU-002', ['WU-001'], ['a.ts'])];
  const r = computeReadiness({ wus, statusOf: statuses({ 'WU-001': 'PENDING' }), maxParallel: 3, isolateFileScope: true });
  assert.deepEqual(r.ready, ['WU-001']);
  assert.equal(r.blocked['WU-002'].reason, 'deps');
}

// concurrency cap STILL applies under isolation: 3 overlapping ready, cap=2
{
  const wus = [
    wu('WU-001', [], ['shared.ts']),
    wu('WU-002', [], ['shared.ts']),
    wu('WU-003', [], ['shared.ts']),
  ];
  const r = computeReadiness({ wus, statusOf: statuses({}), maxParallel: 2, isolateFileScope: true });
  assert.equal(r.ready.length, 2);
  const capped = Object.entries(r.blocked).filter(([, v]) => v.reason === 'concurrency_cap');
  assert.equal(capped.length, 1);
}

// cycle STILL throws under isolation
{
  const wus = [wu('WU-001', ['WU-002'], ['a.ts']), wu('WU-002', ['WU-001'], ['b.ts'])];
  assert.throws(
    () => computeReadiness({ wus, statusOf: statuses({}), maxParallel: 3, isolateFileScope: true }),
    /cycle/i
  );
}

// parsePlan: ambiguous-plan warning SUPPRESSED under isolation, PRESENT without it
{
  const plan = [
    '## Work Units',
    '### WU-001:',
    '- file_scope:',
    '  - shared.ts',
    '### WU-002:',
    '- file_scope:',
    '  - shared.ts',
  ].join('\n');

  const withoutIso = parsePlan(plan, false);
  assert.equal(withoutIso.warnings.length, 1, 'shared file with no dep ordering must warn in default mode');

  const withIso = parsePlan(plan, true);
  assert.deepEqual(withIso.warnings, [], 'isolation suppresses the ambiguous-plan warning');
}

console.log('tl-telar-wu-scheduler isolation: all tests passed');
