#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { mergeDelta, parseDeltaHeader } = require('./tl-telar-spec-merge');

const PLUGIN_ROOT = path.join(__dirname, '..');
const PROJECT_ROOT = process.env.CLAUDE_PROJECT_DIR || process.cwd();

function fail(message) {
  console.error(`ERROR: ${message}`);
  process.exit(1);
}

function usage() {
  console.error('Usage: node scripts/tl-telar-spec-archive.js <change-id>');
  process.exit(2);
}

function sha256(content) {
  return crypto.createHash('sha256').update(content, 'utf8').digest('hex');
}

function readIfExists(filePath) {
  return fs.existsSync(filePath) ? fs.readFileSync(filePath, 'utf8') : null;
}

// Single-domain changes use tl-telar-spec/changes/<id>/REQUIREMENTS.delta.md.
// Multi-domain changes use a deltas/ subfolder, one *.REQUIREMENTS.delta.md
// file per touched domain (see the design doc's "Çoklu-domain change'ler").
function findDeltaFiles(changeDir) {
  const singleDelta = path.join(changeDir, 'REQUIREMENTS.delta.md');
  if (fs.existsSync(singleDelta)) {
    return [singleDelta];
  }
  const deltasDir = path.join(changeDir, 'deltas');
  if (fs.existsSync(deltasDir)) {
    return fs
      .readdirSync(deltasDir)
      .filter((name) => name.endsWith('.REQUIREMENTS.delta.md'))
      .map((name) => path.join(deltasDir, name));
  }
  return [];
}

function main() {
  if (PROJECT_ROOT === PLUGIN_ROOT) {
    fail('archive was invoked against the plugin install directory, not a consumer project. Run from your consumer mobile project.');
  }

  const changeId = process.argv[2];
  if (!changeId) usage();

  const changeDir = path.join(PROJECT_ROOT, 'tl-telar-spec', 'changes', changeId);
  if (!fs.existsSync(changeDir)) {
    fail(`change directory not found: tl-telar-spec/changes/${changeId}/`);
  }

  const deltaFiles = findDeltaFiles(changeDir);
  if (deltaFiles.length === 0) {
    fail(`no delta files found under tl-telar-spec/changes/${changeId}/ (expected REQUIREMENTS.delta.md or deltas/*.REQUIREMENTS.delta.md)`);
  }

  const plannedWrites = [];
  const allConflicts = [];

  // First pass: parse every delta's header, track how many files claim each domain.
  const parsed = [];
  const filesByDomain = new Map();

  for (const deltaFile of deltaFiles) {
    const deltaContent = fs.readFileSync(deltaFile, 'utf8');
    let header;
    try {
      header = parseDeltaHeader(deltaContent);
    } catch (err) {
      allConflicts.push(`${path.relative(PROJECT_ROOT, deltaFile)}: ${err.message}`);
      continue;
    }
    parsed.push({ deltaFile, deltaContent, header });
    if (!filesByDomain.has(header.domain)) filesByDomain.set(header.domain, []);
    filesByDomain.get(header.domain).push(deltaFile);
  }

  // A domain claimed by more than one delta file in this change cannot be
  // merged safely: each delta is computed independently against the same
  // on-disk truth, so merging both would silently drop whichever is written
  // first. Refuse rather than picking a winner.
  const duplicateDomains = new Set();
  for (const [domain, files] of filesByDomain) {
    if (files.length > 1) {
      duplicateDomains.add(domain);
      allConflicts.push(
        `${domain}: targeted by ${files.length} delta files in this change (${files
          .map((f) => path.relative(PROJECT_ROOT, f))
          .join(', ')}) — merge them into a single delta file before archiving.`
      );
    }
  }

  for (const { deltaFile, deltaContent, header } of parsed) {
    if (duplicateDomains.has(header.domain)) continue;

    const truthPath = path.join(PROJECT_ROOT, 'tl-telar-spec', 'truth', header.domain, 'REQUIREMENTS.md');
    const truthContent = readIfExists(truthPath);
    const currentState = truthContent === null ? 'none' : sha256(truthContent);

    if (currentState !== header.baselineHash) {
      allConflicts.push(
        `${header.domain}: truth/${header.domain}/REQUIREMENTS.md changed since this delta's baseline ` +
          `(expected ${header.baselineHash}, found ${currentState}) — another change archived to this domain first. Resolve manually.`
      );
      continue;
    }

    const { mergedContent, conflicts } = mergeDelta({ truthContent: truthContent || '', deltaContent });
    if (conflicts.length > 0) {
      allConflicts.push(...conflicts.map((c) => `${header.domain}: ${c}`));
      continue;
    }

    plannedWrites.push({ truthPath, mergedContent });
  }

  if (allConflicts.length > 0) {
    console.error('Archive ABORTED — conflicts found (no files were changed):');
    for (const c of allConflicts) console.error(`  - ${c}`);
    process.exit(1);
  }

  const dateStamp = new Date().toISOString().slice(0, 10);
  const archiveDir = path.join(PROJECT_ROOT, 'tl-telar-spec', 'changes', 'archive', `${dateStamp}-${changeId}`);
  if (fs.existsSync(archiveDir)) {
    fail(`archive destination already exists: tl-telar-spec/changes/archive/${dateStamp}-${changeId}/ — resolve manually before re-running.`);
  }

  for (const { truthPath, mergedContent } of plannedWrites) {
    fs.mkdirSync(path.dirname(truthPath), { recursive: true });
    fs.writeFileSync(truthPath, mergedContent, 'utf8');
  }

  fs.mkdirSync(path.dirname(archiveDir), { recursive: true });
  fs.renameSync(changeDir, archiveDir);

  console.log(`Archived tl-telar-spec/changes/${changeId}/ -> tl-telar-spec/changes/archive/${dateStamp}-${changeId}/`);
  for (const { truthPath: writtenPath } of plannedWrites) {
    console.log(`  merged into ${path.relative(PROJECT_ROOT, writtenPath)}`);
  }
}

main();
