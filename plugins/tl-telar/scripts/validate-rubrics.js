#!/usr/bin/env node

/**
 * Validates orchestration rubric files have required structure.
 * Scoped to resources/rubrics/orchestration/ only. Other rubric subdirs
 * (e.g., store/, perf/, security/) are out of scope for this validator
 * and may use different section profiles; add per-domain validators as
 * those domains land.
 *
 * Usage: node scripts/validate-rubrics.js
 * Exit 0 = all valid; exit 1 = at least one rubric malformed.
 */

const fs = require('fs');
const path = require('path');

const RUBRICS_ROOT = path.join(__dirname, '..', 'resources', 'rubrics', 'orchestration');
const REQUIRED_SECTIONS = [
  '# ',                       // title
  '## Purpose',
  '## Reviewer mode',         // who uses this rubric (collaborative/adversarial)
  '## Evaluation criteria',
  '## Verdict format',
];

// Layer A exception: vendored verbatim ports must not be edited.
// external-tool-review-rubric.md is vendored byte-for-byte from upstream
// (see THIRD_PARTY_NOTICES.md)
// and uses a different (but semantically equivalent) section profile:
//   "## Overview"         covers ## Purpose (explains who uses it and why)
//   "## Review Checklist" covers ## Evaluation criteria (the per-item checklist)
//   "## Verdict"          covers ## Verdict format (PASS/FAIL table)
// There is no "## Reviewer mode" header; the adversarial reviewer context is
// described inline in ## Overview ("adversarial: assume nothing works...").
const ALTERNATE_PROFILES = {
  'external-tool-review-rubric.md': [
    '# ',                       // title
    '## Overview',              // covers ## Purpose
    '## Review Checklist',      // covers ## Evaluation criteria
    '## Verdict',               // covers ## Verdict format
    // Note: no ## Reviewer mode equivalent; adversarial context is in ## Overview
  ],
};

let errors = 0;
let filesChecked = 0;

function log(level, file, message) {
  const prefix = level === 'ERROR' ? '\x1b[31mERROR\x1b[0m' : '\x1b[33mWARN\x1b[0m';
  console.log(`  ${prefix}: ${file} - ${message}`);
  if (level === 'ERROR') errors++;
}

function findRubrics(dir) {
  if (!fs.existsSync(dir)) return [];
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...findRubrics(full));
    else if (entry.name.endsWith('.md')) out.push(full);
  }
  return out;
}

function validateRubric(rubricPath) {
  const fileName = path.relative(RUBRICS_ROOT, rubricPath);
  const baseName = path.basename(rubricPath);
  const content = fs.readFileSync(rubricPath, 'utf8');
  // Use alternate section profile for vendored verbatim ports (Layer A integrity).
  const sections = ALTERNATE_PROFILES[baseName] || REQUIRED_SECTIONS;
  const missing = sections.filter(s => !content.includes(s));
  if (missing.length > 0) {
    for (const m of missing) {
      log('ERROR', fileName, `missing section: ${m.trim()}`);
    }
  }
  filesChecked++;
}

// Main
console.log('\n\x1b[1mValidating Orchestration Rubrics\x1b[0m\n');

const rubrics = findRubrics(RUBRICS_ROOT);
if (rubrics.length === 0) {
  console.log('No orchestration rubrics found at', RUBRICS_ROOT);
  process.exit(0);
}

console.log(`Found ${rubrics.length} rubric files\n`);

for (const rubric of rubrics.sort()) {
  validateRubric(rubric);
}

// Summary
console.log(`\n${'─'.repeat(50)}`);
console.log(`\x1b[1mResults:\x1b[0m ${filesChecked} files checked`);
if (errors > 0) {
  console.log(`\x1b[31m  ${errors} error(s)\x1b[0m`);
}
if (errors === 0) {
  console.log('\x1b[32m  All rubrics passed validation!\x1b[0m');
}
console.log();

process.exit(errors > 0 ? 1 : 0);
