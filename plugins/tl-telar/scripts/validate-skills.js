#!/usr/bin/env node

/**
 * Validates all skill files in the skills/ directory.
 * Checks:
 * - Required YAML frontmatter fields
 * - Problem/Solution sections (for rewritten skills with impact field)
 * - Code examples with language tags
 * - Code-block language tag presence
 * - Matching entry in plugin.json (warning only)
 */

const fs = require('fs');
const path = require('path');

const SKILLS_DIR = path.join(__dirname, '..', 'skills');
const PLUGIN_JSON = path.join(__dirname, '..', '.claude-plugin', 'plugin.json');

const REQUIRED_FRONTMATTER = ['id', 'category', 'tags', 'capabilities', 'useWhen'];
const ENHANCED_FRONTMATTER = ['impact', 'impactDescription'];
const VALID_IMPACTS = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];

let errors = 0;
let warnings = 0;
let filesChecked = 0;

function log(level, file, message) {
  const prefix = level === 'ERROR' ? '\x1b[31mERROR\x1b[0m' : '\x1b[33mWARN\x1b[0m';
  console.log(`  ${prefix}: ${file} - ${message}`);
  if (level === 'ERROR') errors++;
  else warnings++;
}

function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return null;

  const yaml = match[1];
  const fields = {};

  // Simple YAML parser for our needs
  let currentKey = null;
  let currentList = null;

  for (const line of yaml.split('\n')) {
    const keyMatch = line.match(/^(\w+):\s*(.*)/);
    if (keyMatch) {
      if (currentKey && currentList) {
        fields[currentKey] = currentList;
      }
      currentKey = keyMatch[1];
      const value = keyMatch[2].trim();

      if (value === '' || value === '|') {
        currentList = [];
      } else if (value.startsWith('[') && value.endsWith(']')) {
        fields[currentKey] = value.slice(1, -1).split(',').map(s => s.trim().replace(/"/g, ''));
        currentKey = null;
        currentList = null;
      } else if (value === 'true' || value === 'false') {
        fields[currentKey] = value === 'true';
        currentKey = null;
        currentList = null;
      } else if (!isNaN(value) && value !== '') {
        fields[currentKey] = Number(value);
        currentKey = null;
        currentList = null;
      } else {
        fields[currentKey] = value.replace(/^["']|["']$/g, '');
        currentKey = null;
        currentList = null;
      }
    } else if (line.match(/^\s+-\s+/)) {
      if (!currentList) currentList = [];
      currentList.push(line.replace(/^\s+-\s+/, '').trim().replace(/^["']|["']$/g, ''));
    }
  }
  if (currentKey && currentList) {
    fields[currentKey] = currentList;
  }

  return fields;
}

function validateSkill(filePath) {
  const fileName = path.relative(SKILLS_DIR, filePath);
  const content = fs.readFileSync(filePath, 'utf-8');

  // Check frontmatter exists
  const frontmatter = parseFrontmatter(content);
  if (!frontmatter) {
    log('ERROR', fileName, 'Missing YAML frontmatter (---...---)');
    return;
  }

  // Check required fields
  for (const field of REQUIRED_FRONTMATTER) {
    if (!(field in frontmatter)) {
      log('ERROR', fileName, `Missing required frontmatter field: ${field}`);
    }
  }

  // Check category
  if (frontmatter.category && frontmatter.category !== 'skill') {
    log('ERROR', fileName, `Category must be "skill", got "${frontmatter.category}"`);
  }

  // Check arrays
  if (frontmatter.tags && !Array.isArray(frontmatter.tags)) {
    log('ERROR', fileName, 'tags must be an array');
  }
  if (frontmatter.capabilities && !Array.isArray(frontmatter.capabilities)) {
    log('ERROR', fileName, 'capabilities must be an array');
  }
  if (frontmatter.useWhen && !Array.isArray(frontmatter.useWhen)) {
    log('ERROR', fileName, 'useWhen must be an array');
  }

  // Check enhanced fields (if present)
  if (frontmatter.impact) {
    if (!VALID_IMPACTS.includes(frontmatter.impact)) {
      log('ERROR', fileName, `Invalid impact level: "${frontmatter.impact}". Must be one of: ${VALID_IMPACTS.join(', ')}`);
    }
    if (!frontmatter.impactDescription) {
      log('WARN', fileName, 'Has impact but missing impactDescription');
    }
  }

  // Check for Problem/Solution sections (enhanced skills with impact)
  if (frontmatter.impact) {
    if (!content.includes('## Problem')) {
      log('WARN', fileName, 'Enhanced skill missing "## Problem" section');
    }
    if (!content.includes('## Solution')) {
      log('WARN', fileName, 'Enhanced skill missing "## Solution" section');
    }
  }

  // Check for code examples
  const codeBlockMatch = content.match(/```(\w+)/g);
  if (!codeBlockMatch || codeBlockMatch.length === 0) {
    log('WARN', fileName, 'No code examples found (expected ```language blocks)');
  }

  // Check code blocks have language tags. Counts only opening fences
  // (state machine over lines) so closing fences are not double-counted.
  let untaggedOpens = 0;
  let inBlock = false;
  for (const line of content.split('\n')) {
    if (!inBlock && line === '```') { untaggedOpens++; inBlock = true; }
    else if (!inBlock && /^```[a-zA-Z]/.test(line)) { inBlock = true; }
    else if (inBlock && line === '```') { inBlock = false; }
  }
  if (untaggedOpens > 0) {
    log('WARN', fileName, `${untaggedOpens} code block(s) without language tag`);
  }

  // Orchestration skills have additional structural requirements
  // (Trigger condition + no-legacy-auto-trigger + anti-patterns sections).
  if (filePath.includes(path.sep + 'orchestration' + path.sep)) {
    if (!/^## Trigger condition(\s|$)/m.test(content)) {
      log('ERROR', fileName, 'orchestration skill missing "## Trigger condition" section (master design §1.1)');
    }
    if (!/never.*auto-triggered.*legacy|never.*legacy.*command/i.test(content)) {
      log('ERROR', fileName, 'orchestration skill missing explicit "never auto-triggered from legacy commands" statement');
    }
    if (!/## Anti-patterns|## Things NOT to do/i.test(content)) {
      log('ERROR', fileName, 'orchestration skill missing anti-patterns section');
    }
  }

  filesChecked++;
}

function getSkillFiles(dir) {
  const files = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      // Skip `references/` subdirectories — they hold supplementary material
      // (verdict schemas, prompt templates) which are not skills themselves
      // and don't have skill frontmatter.
      if (entry.name === 'references') continue;
      // Recurse into other subdirectories (e.g., learn-pattern/, orchestration/)
      files.push(...getSkillFiles(fullPath));
    } else if (entry.name.endsWith('.md') && !entry.name.startsWith('_')) {
      files.push(fullPath);
    }
  }

  return files;
}

// Main
console.log('\n\x1b[1mValidating Skills\x1b[0m\n');

const skillFiles = getSkillFiles(SKILLS_DIR);
console.log(`Found ${skillFiles.length} skill files\n`);

for (const file of skillFiles.sort()) {
  validateSkill(file);
}

// Summary
console.log(`\n${'─'.repeat(50)}`);
console.log(`\x1b[1mResults:\x1b[0m ${filesChecked} files checked`);
if (errors > 0) {
  console.log(`\x1b[31m  ${errors} error(s)\x1b[0m`);
}
if (warnings > 0) {
  console.log(`\x1b[33m  ${warnings} warning(s)\x1b[0m`);
}
if (errors === 0 && warnings === 0) {
  console.log('\x1b[32m  All skills passed validation!\x1b[0m');
}
console.log();

process.exit(errors > 0 ? 1 : 0);
