#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const { mergeDelta, parseDeltaHeader } = require('../../scripts/tl-telar-spec-merge');

const TRUTH = `# Requirements: Auth Domain

## Functional Requirements

### F-1: Login
**Description:** Users can log in with email/password.
**Phase:** 1

### F-2: Guest Checkout
**Description:** Users can check out without an account.
**Phase:** 1
`;

// parseDeltaHeader extracts domain + baseline-hash
{
  const delta = '<!-- tl-telar-spec-delta: domain=auth baseline-hash=abc123 -->\n# Delta\n';
  const header = parseDeltaHeader(delta);
  assert.deepEqual(header, { domain: 'auth', baselineHash: 'abc123' });
}

// parseDeltaHeader throws when the header comment is missing
{
  assert.throws(() => parseDeltaHeader('# Delta with no header\n'), /missing required header/);
}

// ADDED requirement appends a new F-x block, leaves existing blocks untouched
{
  const delta = `<!-- tl-telar-spec-delta: domain=auth baseline-hash=none -->
## ADDED Requirements
### F-3: Two-Factor Authentication
**Description:** Users can enable TOTP-based 2FA.
**Phase:** 2
`;
  const { mergedContent, conflicts } = mergeDelta({ truthContent: TRUTH, deltaContent: delta });
  assert.deepEqual(conflicts, []);
  assert.match(mergedContent, /### F-3: Two-Factor Authentication/);
  assert.match(mergedContent, /### F-1: Login/);
}

// MODIFIED replaces an existing block's content
{
  const delta = `<!-- tl-telar-spec-delta: domain=auth baseline-hash=none -->
## MODIFIED Requirements
### F-1: Login
**Description:** Users can log in with email/password OR a magic link.
**Phase:** 1
`;
  const { mergedContent, conflicts } = mergeDelta({ truthContent: TRUTH, deltaContent: delta });
  assert.deepEqual(conflicts, []);
  assert.match(mergedContent, /magic link/);
}

// REMOVED marks the block deprecated — never deletes it
{
  const delta = `<!-- tl-telar-spec-delta: domain=auth baseline-hash=none -->
## REMOVED Requirements
### F-2: Guest Checkout
**Reason:** Superseded by F-3.
`;
  const { mergedContent, conflicts } = mergeDelta({ truthContent: TRUTH, deltaContent: delta });
  assert.deepEqual(conflicts, []);
  assert.match(mergedContent, /### F-2: Guest Checkout/);
  assert.match(mergedContent, /\*\*Status:\*\* deprecated/);
}

// ADDED conflict — F-id already exists in truth
{
  const delta = `<!-- tl-telar-spec-delta: domain=auth baseline-hash=none -->
## ADDED Requirements
### F-1: Duplicate Login
**Description:** This should conflict.
`;
  const { mergedContent, conflicts } = mergeDelta({ truthContent: TRUTH, deltaContent: delta });
  assert.equal(mergedContent, null);
  assert.equal(conflicts.length, 1);
  assert.match(conflicts[0], /F-1 already exists/);
}

// MODIFIED conflict — F-id not found in truth
{
  const delta = `<!-- tl-telar-spec-delta: domain=auth baseline-hash=none -->
## MODIFIED Requirements
### F-9: Nonexistent
**Description:** This should conflict.
`;
  const { mergedContent, conflicts } = mergeDelta({ truthContent: TRUTH, deltaContent: delta });
  assert.equal(mergedContent, null);
  assert.equal(conflicts.length, 1);
  assert.match(conflicts[0], /F-9 not found/);
}

// Blank-line fidelity: preamble/first-block boundary must round-trip exactly
{
  const delta = `<!-- tl-telar-spec-delta: domain=auth baseline-hash=none -->
## ADDED Requirements
### F-3: Two-Factor Authentication
**Description:** Users can enable TOTP-based 2FA.
**Phase:** 2
`;
  const { mergedContent, conflicts } = mergeDelta({ truthContent: TRUTH, deltaContent: delta });
  assert.deepEqual(conflicts, []);
  // The blank line between "## Functional Requirements" and "### F-1: Login"
  // in TRUTH must survive the merge unchanged.
  assert.equal(mergedContent.includes('## Functional Requirements\n\n### F-1: Login'), true);
}

// Blank-line fidelity: merging into empty truth content must not insert a
// spurious leading blank line before the first block.
{
  const delta = `<!-- tl-telar-spec-delta: domain=auth baseline-hash=none -->
## ADDED Requirements
### F-1: First Ever Requirement
**Description:** First requirement in a brand-new domain.
`;
  const { mergedContent, conflicts } = mergeDelta({ truthContent: '', deltaContent: delta });
  assert.deepEqual(conflicts, []);
  assert.equal(mergedContent.startsWith('### F-1: First Ever Requirement'), true);
}

console.log('tl-telar-spec-merge: all tests passed');
