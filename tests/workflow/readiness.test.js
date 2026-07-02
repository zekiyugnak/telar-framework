#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const { computeReadiness } = require('../../scripts/tl-telar-wu-scheduler');

// Helper: build a statusOf function from a plain object, defaulting to PENDING.
const statuses = (obj) => (id) => obj[id] || 'PENDING';

const wu = (id, deps, fileScope) => ({ id, deps, fileScope });

// deps gating: WU-002 depends on incomplete WU-001 -> blocked "deps"
{
  const wus = [wu('WU-001', [], ['a.ts']), wu('WU-002', ['WU-001'], ['b.ts'])];
  const r = computeReadiness({ wus, statusOf: statuses({ 'WU-001': 'PENDING' }), maxParallel: 3 });
  assert.deepEqual(r.ready, ['WU-001']);
  assert.equal(r.blocked['WU-002'].reason, 'deps');
}

// deps satisfied -> dependent becomes ready
{
  const wus = [wu('WU-001', [], ['a.ts']), wu('WU-002', ['WU-001'], ['b.ts'])];
  const r = computeReadiness({ wus, statusOf: statuses({ 'WU-001': 'COMPLETE' }), maxParallel: 3 });
  assert.deepEqual(r.ready, ['WU-002']);
}

// file conflict vs a RUNNING WU -> blocked "file_conflict"
{
  const wus = [wu('WU-001', [], ['shared.ts']), wu('WU-002', [], ['shared.ts'])];
  const r = computeReadiness({ wus, statusOf: statuses({ 'WU-001': 'IN-PROGRESS' }), maxParallel: 3 });
  assert.deepEqual(r.ready, []);
  assert.equal(r.blocked['WU-002'].reason, 'file_conflict');
  assert.deepEqual(r.running, ['WU-001']);
  assert.deepEqual(r.occupied_files, ['shared.ts']);
}

// internal disjointness: two PENDING candidates overlapping EACH OTHER ->
// only one admitted to ready
{
  const wus = [wu('WU-001', [], ['shared.ts']), wu('WU-002', [], ['shared.ts'])];
  const r = computeReadiness({ wus, statusOf: statuses({}), maxParallel: 3 });
  assert.equal(r.ready.length, 1);
  assert.equal(r.blocked[r.ready[0] === 'WU-001' ? 'WU-002' : 'WU-001'].reason, 'file_conflict');
}

// two disjoint PENDING candidates both admitted
{
  const wus = [wu('WU-001', [], ['a.ts']), wu('WU-002', [], ['b.ts'])];
  const r = computeReadiness({ wus, statusOf: statuses({}), maxParallel: 3 });
  assert.deepEqual(r.ready.sort(), ['WU-001', 'WU-002']);
}

// concurrency cap: 3 disjoint ready but cap=2 -> 2 ready, 1 concurrency_cap
{
  const wus = [wu('WU-001', [], ['a.ts']), wu('WU-002', [], ['b.ts']), wu('WU-003', [], ['c.ts'])];
  const r = computeReadiness({ wus, statusOf: statuses({}), maxParallel: 2 });
  assert.equal(r.ready.length, 2);
  const capped = Object.entries(r.blocked).filter(([, v]) => v.reason === 'concurrency_cap');
  assert.equal(capped.length, 1);
}

// cap counts RUNNING WUs: 1 running + cap=2 -> only 1 more admitted
{
  const wus = [wu('WU-001', [], ['a.ts']), wu('WU-002', [], ['b.ts']), wu('WU-003', [], ['c.ts'])];
  const r = computeReadiness({ wus, statusOf: statuses({ 'WU-001': 'IN-PROGRESS' }), maxParallel: 2 });
  assert.equal(r.ready.length, 1);
}

// critical-path ordering: under cap=1, the WU on the longer chain is admitted first.
// WU-A blocks a 2-deep chain (WU-B -> WU-C); WU-D is a standalone leaf.
{
  const wus = [
    wu('WU-A', [], ['a.ts']),
    wu('WU-B', ['WU-A'], ['b.ts']),
    wu('WU-C', ['WU-B'], ['c.ts']),
    wu('WU-D', [], ['d.ts']),
  ];
  const r = computeReadiness({ wus, statusOf: statuses({}), maxParallel: 1 });
  assert.deepEqual(r.ready, ['WU-A']); // longer remaining chain beats the leaf
}

// critical-path ordering must use the SUCCESSOR chain, not the (already-satisfied)
// ancestor chain: WU-A has a fully-complete 2-deep ancestor chain but unlocks
// nothing further; WU-B has no ancestors but is the head of a 3-deep still-PENDING
// successor chain. Under cap=1, WU-B (the real long pole) must be admitted first.
{
  const wus = [
    wu('WU-Y', [], ['y.ts']),
    wu('WU-X', ['WU-Y'], ['x.ts']),
    wu('WU-A', ['WU-X'], ['a.ts']), // leaf: fully-complete ancestors, no successors
    wu('WU-B', [], ['b.ts']),
    wu('WU-C', ['WU-B'], ['c.ts']),
    wu('WU-D', ['WU-C'], ['d.ts']),
    wu('WU-E', ['WU-D'], ['e.ts']),
  ];
  const statusOf = statuses({ 'WU-Y': 'COMPLETE', 'WU-X': 'COMPLETE' });
  const r = computeReadiness({ wus, statusOf, maxParallel: 1 });
  assert.deepEqual(r.ready, ['WU-B']); // long pole beats the completed-ancestor leaf
}

// cycle -> throw
{
  const wus = [wu('WU-001', ['WU-002'], ['a.ts']), wu('WU-002', ['WU-001'], ['b.ts'])];
  assert.throws(() => computeReadiness({ wus, statusOf: statuses({}), maxParallel: 3 }), /cycle/i);
}

// COMPLETE WUs are neither ready nor running nor blocked
{
  const wus = [wu('WU-001', [], ['a.ts']), wu('WU-002', ['WU-001'], ['b.ts'])];
  const r = computeReadiness({ wus, statusOf: statuses({ 'WU-001': 'COMPLETE', 'WU-002': 'COMPLETE' }), maxParallel: 3 });
  assert.deepEqual(r.ready, []);
  assert.deepEqual(r.running, []);
  assert.deepEqual(Object.keys(r.blocked), []);
}

console.log('tl-telar-wu-scheduler readiness: all tests passed');
