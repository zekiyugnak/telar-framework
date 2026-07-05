#!/usr/bin/env node

/**
 * Validates all agent files in the agents/ directory.
 * Checks:
 * - Required YAML frontmatter fields
 * - Decision Framework section (for enhanced agents)
 * - Anti-Patterns section
 * - Skill references
 */

const fs = require('fs');
const path = require('path');

const AGENTS_DIR = path.join(__dirname, '..', 'agents');

const REQUIRED_FRONTMATTER = ['id', 'category', 'tags', 'capabilities', 'useWhen'];

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
      currentList.push(line.replace(/^\s+-\s+/, '').trim());
    }
  }
  if (currentKey && currentList) {
    fields[currentKey] = currentList;
  }

  return fields;
}

function validateAgent(filePath) {
  const fileName = path.basename(filePath);
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
  if (frontmatter.category && frontmatter.category !== 'agent') {
    log('ERROR', fileName, `Category must be "agent", got "${frontmatter.category}"`);
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

  // Check for enhanced sections
  const hasDecisionFramework = frontmatter.decisionFramework ||
    content.includes('## Decision Framework') ||
    content.includes('## Decision Tree') ||
    content.includes('Decision Tree');

  const hasAntiPatterns = content.includes('## Anti-Patterns') ||
    content.includes('## Anti-Pattern') ||
    content.includes('### Anti-Pattern');

  const hasEscalation = content.includes('## Escalation') ||
    content.includes('Escalation Path') ||
    content.includes('Hand Off To');

  const hasToolCommands = content.includes('## Tool Commands') ||
    content.includes('## CLI Commands') ||
    content.includes('Tool Commands');

  // Check for Decision Framework
  if (!hasDecisionFramework) {
    log('WARN', fileName, 'Missing Decision Framework section');
  }

  // Check for Anti-Patterns
  if (!hasAntiPatterns) {
    log('WARN', fileName, 'Missing Anti-Patterns section');
  }

  // Check for Escalation Paths
  if (!hasEscalation) {
    log('WARN', fileName, 'Missing Escalation Paths section');
  }

  // Check for Tool Commands
  if (!hasToolCommands) {
    log('WARN', fileName, 'Missing Tool Commands section');
  }

  // Check for code examples
  const codeBlocks = content.match(/```(\w+)/g);
  if (!codeBlocks || codeBlocks.length === 0) {
    log('WARN', fileName, 'No code examples found');
  }

  // Check for Best Practices or Common Pitfalls
  if (!content.includes('## Best Practices') && !content.includes('## Common Pitfalls')) {
    log('WARN', fileName, 'Missing Best Practices or Common Pitfalls section');
  }

  filesChecked++;
}

// Main
console.log('\n\x1b[1mValidating Agents\x1b[0m\n');

const agentFiles = fs.readdirSync(AGENTS_DIR)
  .filter(f => f.endsWith('.md') && !f.startsWith('_'))
  .map(f => path.join(AGENTS_DIR, f))
  .sort();

console.log(`Found ${agentFiles.length} agent files\n`);

for (const file of agentFiles) {
  validateAgent(file);
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
  console.log('\x1b[32m  All agents passed validation!\x1b[0m');
}
console.log();

process.exit(errors > 0 ? 1 : 0);
