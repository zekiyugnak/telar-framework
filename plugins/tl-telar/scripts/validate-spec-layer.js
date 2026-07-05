#!/usr/bin/env node

/**
 * Validates the Spec Layer structure of a consumer project.
 * Checks:
 * - Every changes/<id>/*.delta.md (root or deltas/) has a valid
 *   <!-- tl-telar-spec-delta: domain=... baseline-hash=... --> header
 * - No empty deltas/ directories
 * - Every truth/<domain>/REQUIREMENTS.md contains at least one F-x block
 */

const fs = require('fs');
const path = require('path');
const { parseDeltaHeader } = require('./tl-telar-spec-merge');

const PROJECT_ROOT = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const SPEC_ROOT = path.join(PROJECT_ROOT, 'tl-telar-spec');

let errors = 0;
let warnings = 0;

function log(level, file, message) {
  const prefix = level === 'ERROR' ? '\x1b[31mERROR\x1b[0m' : '\x1b[33mWARN\x1b[0m';
  console.log(`  ${prefix}: ${file} - ${message}`);
  if (level === 'ERROR') errors++;
  else warnings++;
}

function checkDeltaFile(filePath) {
  const rel = path.relative(PROJECT_ROOT, filePath);
  const content = fs.readFileSync(filePath, 'utf8');
  try {
    parseDeltaHeader(content);
  } catch (err) {
    log('ERROR', rel, err.message);
  }
}

function checkChanges() {
  const changesDir = path.join(SPEC_ROOT, 'changes');
  if (!fs.existsSync(changesDir)) return;

  for (const entry of fs.readdirSync(changesDir)) {
    if (entry === 'archive') continue;
    const changeDir = path.join(changesDir, entry);
    if (!fs.statSync(changeDir).isDirectory()) continue;

    const singleDelta = path.join(changeDir, 'REQUIREMENTS.delta.md');
    if (fs.existsSync(singleDelta)) checkDeltaFile(singleDelta);

    const deltasDir = path.join(changeDir, 'deltas');
    if (fs.existsSync(deltasDir)) {
      const files = fs.readdirSync(deltasDir).filter((f) => f.endsWith('.REQUIREMENTS.delta.md'));
      if (files.length === 0) {
        log('WARN', path.relative(PROJECT_ROOT, deltasDir), 'deltas/ directory exists but is empty');
      }
      for (const f of files) checkDeltaFile(path.join(deltasDir, f));
    }
  }
}

function checkTruth() {
  const truthDir = path.join(SPEC_ROOT, 'truth');
  if (!fs.existsSync(truthDir)) return;

  for (const domain of fs.readdirSync(truthDir)) {
    const reqPath = path.join(truthDir, domain, 'REQUIREMENTS.md');
    if (!fs.existsSync(reqPath)) continue;
    const content = fs.readFileSync(reqPath, 'utf8');
    if (!/^###\s+F-\d+:/m.test(content)) {
      log('WARN', path.relative(PROJECT_ROOT, reqPath), 'no F-x requirement blocks found');
    }
  }
}

if (!fs.existsSync(SPEC_ROOT)) {
  console.log('tl-telar-spec/ not present — nothing to validate.');
  process.exit(0);
}

checkChanges();
checkTruth();

console.log('');
console.log(`Spec Layer validation: ${errors} errors, ${warnings} warnings`);
process.exit(errors > 0 ? 1 : 0);
