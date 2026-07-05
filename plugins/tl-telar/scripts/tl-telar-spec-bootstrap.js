#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { inferDomain } = require('./tl-telar-spec-domain');

const PLUGIN_ROOT = path.join(__dirname, '..');
const PROJECT_ROOT = process.env.CLAUDE_PROJECT_DIR || process.cwd();

function fail(message) {
  console.error(`ERROR: ${message}`);
  process.exit(1);
}

function ensureSkeleton() {
  const dirs = [
    path.join(PROJECT_ROOT, 'tl-telar-spec', 'truth'),
    path.join(PROJECT_ROOT, 'tl-telar-spec', 'changes'),
    path.join(PROJECT_ROOT, 'tl-telar-spec', 'changes', 'archive'),
  ];
  for (const dir of dirs) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

// Extracts file_scope entries from a PLAN.md's Work Unit blocks (schema:
// skills/orchestration/orchestrated-execution/references/work-unit-schema.md).
// Looks for `file_scope:` followed by indented `- path` list items — a
// deliberately small extractor, not a full YAML parser.
function extractFileScopePaths(planContent) {
  const paths = [];
  const lines = planContent.split('\n');
  let inFileScope = false;
  for (const line of lines) {
    if (/^\s*file_scope:\s*$/.test(line)) {
      inFileScope = true;
      continue;
    }
    if (inFileScope) {
      const itemMatch = line.match(/^\s*-\s*(\S+)/);
      if (itemMatch) {
        paths.push(itemMatch[1]);
        continue;
      }
      inFileScope = false;
    }
  }
  return paths;
}

function migrateRootArtifacts() {
  const rootRequirements = path.join(PROJECT_ROOT, 'REQUIREMENTS.md');
  if (!fs.existsSync(rootRequirements)) {
    return { migrated: false };
  }

  const rootPlan = path.join(PROJECT_ROOT, 'PLAN.md');
  const planContent = fs.existsSync(rootPlan) ? fs.readFileSync(rootPlan, 'utf8') : '';
  const scopePaths = extractFileScopePaths(planContent);
  const domain = inferDomain(scopePaths) || 'general';

  const truthDir = path.join(PROJECT_ROOT, 'tl-telar-spec', 'truth', domain);
  const destPath = path.join(truthDir, 'REQUIREMENTS.md');
  if (fs.existsSync(destPath)) {
    fail(
      `cannot migrate: tl-telar-spec/truth/${domain}/REQUIREMENTS.md already exists. ` +
        'Resolve manually (merge or rename) before re-running bootstrap.'
    );
  }

  fs.mkdirSync(truthDir, { recursive: true });
  fs.renameSync(rootRequirements, destPath);

  console.log(`Migrated REQUIREMENTS.md -> tl-telar-spec/truth/${domain}/REQUIREMENTS.md`);
  console.log(`  (domain inferred from PLAN.md file_scope entries — rename the ${domain}/ folder if this guess is wrong)`);
  return { migrated: true, domain };
}

function main() {
  if (PROJECT_ROOT === PLUGIN_ROOT) {
    fail('bootstrap was invoked against the plugin install directory, not a consumer project. Run from your consumer mobile project.');
  }
  ensureSkeleton();
  const result = migrateRootArtifacts();
  if (!result.migrated) {
    console.log('tl-telar-spec/ skeleton ready (no root-level REQUIREMENTS.md found to migrate).');
  }
}

main();
