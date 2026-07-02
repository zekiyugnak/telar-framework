#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const { inferDomain } = require('../../scripts/tl-telar-spec-domain');

// Nested feature folder under known layer roots (src/screens/<domain>/...)
assert.equal(
  inferDomain(['src/screens/auth/LoginScreen.tsx', 'src/screens/auth/__tests__/LoginScreen.test.tsx']),
  'auth'
);

// File directly under a layer root, no feature subfolder — filename becomes the candidate
assert.equal(inferDomain(['src/api/checkout.ts']), 'checkout');

// Majority vote across mixed domains
assert.equal(
  inferDomain([
    'src/screens/auth/A.tsx',
    'src/screens/auth/B.tsx',
    'src/screens/navigation/C.tsx',
  ]),
  'auth'
);

// Empty input → null
assert.equal(inferDomain([]), null);

// All segments are known layer roots → null (no domain candidate found)
assert.equal(inferDomain(['src/lib/app']), null);

console.log('tl-telar-spec-domain: all tests passed');
