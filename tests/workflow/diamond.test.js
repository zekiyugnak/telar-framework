#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { parsePlan, parseState, computeReadiness } = require('../../scripts/tl-telar-wu-scheduler');

const dir = path.join(__dirname, 'fixtures');
const planText = fs.readFileSync(path.join(dir, 'diamond-active-plan.md'), 'utf8');
const stateText = fs.readFileSync(path.join(dir, 'diamond-execution-state.md'), 'utf8');

const { wus, warnings } = parsePlan(planText);
assert.deepEqual(warnings, []); // diamond has no ambiguous shared writes

const statusMap = parseState(stateText);
const statusOf = (id) => statusMap.get(id) || 'PENDING';

// With A COMPLETE, B and C (disjoint scopes) both become ready; D still blocked on B,C.
const r = computeReadiness({ wus, statusOf, maxParallel: 3 });
assert.deepEqual(r.ready.sort(), ['WU-B', 'WU-C']);
assert.equal(r.blocked['WU-D'].reason, 'deps');

// Now simulate B and C running: D still blocked on deps (not file conflict).
const running = (id) => (id === 'WU-B' || id === 'WU-C' ? 'IN-PROGRESS' : statusOf(id));
const r2 = computeReadiness({ wus, statusOf: running, maxParallel: 3 });
assert.deepEqual(r2.ready, []);
assert.deepEqual(r2.running.sort(), ['WU-B', 'WU-C']);
assert.equal(r2.blocked['WU-D'].reason, 'deps');

console.log('tl-telar-wu-scheduler diamond: all tests passed');
