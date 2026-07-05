#!/usr/bin/env node

/**
 * Validates all blueprint files in skills/blueprints/.
 * Checks:
 * - Required YAML frontmatter fields
 * - Both React Native and Flutter implementations
 * - Test section present
 * - Accessibility checklist present
 * - Supabase backend section present
 * - File manifest present
 */

const fs = require('fs');
const path = require('path');

const BLUEPRINTS_DIR = path.join(__dirname, '..', 'skills', 'blueprints');

let errors = 0;
let warnings = 0;
let filesChecked = 0;

function log(level, file, message) {
  const prefix = level === 'ERROR' ? '\x1b[31mERROR\x1b[0m' : '\x1b[33mWARN\x1b[0m';
  console.log(`  ${prefix}: ${file} - ${message}`);
  if (level === 'ERROR') errors++;
  else warnings++;
}

function validateBlueprint(filePath) {
  const fileName = path.basename(filePath);

  // Skip README and non-blueprint files
  if (fileName === 'README.md' || fileName.startsWith('_')) return;

  const content = fs.readFileSync(filePath, 'utf-8');

  // Check frontmatter
  const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---/);
  if (!frontmatterMatch) {
    log('ERROR', fileName, 'Missing YAML frontmatter');
    return;
  }

  const frontmatter = frontmatterMatch[1];

  // Check blueprint-specific frontmatter
  if (!frontmatter.includes('id:')) {
    log('ERROR', fileName, 'Missing id in frontmatter');
  }
  if (!frontmatter.includes('category: skill')) {
    log('ERROR', fileName, 'category must be "skill"');
  }

  // Check for React Native implementation
  const hasRN = content.includes('React Native') || content.includes('react-native') || content.includes('.tsx');
  if (!hasRN) {
    log('ERROR', fileName, 'Missing React Native implementation');
  }

  // Check for Flutter implementation
  const hasFlutter = content.includes('Flutter') || content.includes('flutter') || content.includes('.dart');
  if (!hasFlutter) {
    log('ERROR', fileName, 'Missing Flutter implementation');
  }

  // Check for File Manifest
  if (!content.includes('## File Manifest')) {
    log('ERROR', fileName, 'Missing "## File Manifest" section');
  }

  // Check for tests
  const hasTests = content.includes('## Tests') || content.includes('## Test') || content.includes('__tests__') || content.includes('_test.dart');
  if (!hasTests) {
    log('ERROR', fileName, 'Missing tests section');
  }

  // Check for accessibility
  const hasA11y = content.includes('Accessibility') || content.includes('accessibility') || content.includes('a11y');
  if (!hasA11y) {
    log('ERROR', fileName, 'Missing accessibility section');
  }

  // Check for Supabase backend
  const hasBackend = content.includes('Supabase') || content.includes('Backend') || content.includes('CREATE TABLE');
  if (!hasBackend) {
    log('WARN', fileName, 'Missing Supabase backend section');
  }

  // Check for code examples
  const tsBlocks = (content.match(/```typescript|```tsx/g) || []).length;
  const dartBlocks = (content.match(/```dart/g) || []).length;

  if (tsBlocks === 0) {
    log('WARN', fileName, 'No TypeScript/TSX code blocks found');
  }
  if (dartBlocks === 0) {
    log('WARN', fileName, 'No Dart code blocks found');
  }

  filesChecked++;
}

// Main
console.log('\n\x1b[1mValidating Blueprints\x1b[0m\n');

if (!fs.existsSync(BLUEPRINTS_DIR)) {
  console.log('\x1b[31mBlueprints directory not found: skills/blueprints/\x1b[0m\n');
  process.exit(1);
}

const files = fs.readdirSync(BLUEPRINTS_DIR)
  .filter(f => f.endsWith('.md'))
  .sort();

console.log(`Found ${files.length} blueprint files\n`);

for (const file of files) {
  validateBlueprint(path.join(BLUEPRINTS_DIR, file));
}

// Summary
console.log(`\n${'─'.repeat(50)}`);
console.log(`\x1b[1mResults:\x1b[0m ${filesChecked} blueprints checked`);
if (errors > 0) {
  console.log(`\x1b[31m  ${errors} error(s)\x1b[0m`);
}
if (warnings > 0) {
  console.log(`\x1b[33m  ${warnings} warning(s)\x1b[0m`);
}
if (errors === 0 && warnings === 0) {
  console.log('\x1b[32m  All blueprints passed validation!\x1b[0m');
}
console.log();

process.exit(errors > 0 ? 1 : 0);
