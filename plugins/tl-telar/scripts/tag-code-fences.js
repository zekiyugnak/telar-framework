#!/usr/bin/env node

/**
 * One-shot patcher: walks skills/ and tags every untagged opening code fence.
 * Uses a line-by-line state machine to distinguish opening from closing fences,
 * and infers the language from the first non-empty content line.
 *
 * Inference is conservative — falls back to "text" rather than guessing wrong.
 * Run from repo root: `node scripts/tag-code-fences.js`
 */

const fs = require('fs');
const path = require('path');

const ROOTS = ['skills', 'agents'];

function inferLanguage(blockBody) {
  const firstNonEmpty = (blockBody.find(l => l.trim().length > 0) || '').trim();
  if (!firstNonEmpty) return 'text';

  // Shell — most common case in this plugin
  if (/^(\$|#!\/bin\/(bash|sh)|npm |npx |yarn |pnpm |bun |flutter |pod |gradlew|xcodebuild|cd |git |docker|eas |expo |fastlane|mkdir |cp |rm |chmod |export |source )/.test(firstNonEmpty)) {
    return 'bash';
  }
  // JSON
  if (/^[\[{]/.test(firstNonEmpty) && /[":]/.test(firstNonEmpty)) {
    return 'json';
  }
  // YAML — top-level key followed by colon, or list dash
  if (/^[a-zA-Z][a-zA-Z0-9_-]*:\s*(\S|$)/.test(firstNonEmpty) && !firstNonEmpty.includes('=')) {
    return 'yaml';
  }
  // Dart
  if (/^(import 'package:|class \w+ extends|Widget build|void main|Future<|@override)/.test(firstNonEmpty)) {
    return 'dart';
  }
  // TSX / TypeScript-React (JSX tags or React hooks)
  if (/<[A-Z]\w*[\s/>]|^import .* from ['"]react|^export .* function /.test(firstNonEmpty)) {
    return 'tsx';
  }
  // TypeScript / JavaScript
  if (/^(import |export |const |let |var |function |interface |type |enum |async )/.test(firstNonEmpty)) {
    return 'typescript';
  }
  // SQL
  if (/^(SELECT|INSERT|UPDATE|DELETE|CREATE TABLE|ALTER TABLE|CREATE INDEX|WITH )/i.test(firstNonEmpty)) {
    return 'sql';
  }
  // Markdown (frontmatter or heading)
  if (/^(---|#{1,6} )/.test(firstNonEmpty)) {
    return 'markdown';
  }
  return 'text';
}

function patchFile(filePath) {
  const lines = fs.readFileSync(filePath, 'utf-8').split('\n');
  const out = [];
  let inBlock = false;
  let pendingOpenIdx = -1;
  let pendingBody = [];
  let patches = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!inBlock && line === '```') {
      // Opening fence with no language. Capture body until the closing fence
      // before deciding the language, then patch.
      inBlock = true;
      pendingOpenIdx = out.length;
      pendingBody = [];
      out.push('```'); // placeholder, may be rewritten below
      continue;
    }
    if (!inBlock && /^```[a-zA-Z]/.test(line)) {
      // Already-tagged opening fence
      inBlock = true;
      out.push(line);
      continue;
    }
    if (inBlock && line === '```') {
      // Closing fence
      if (pendingOpenIdx >= 0) {
        const lang = inferLanguage(pendingBody);
        out[pendingOpenIdx] = '```' + lang;
        patches++;
        pendingOpenIdx = -1;
        pendingBody = [];
      }
      inBlock = false;
      out.push('```');
      continue;
    }
    if (inBlock && pendingOpenIdx >= 0) {
      pendingBody.push(line);
    }
    out.push(line);
  }

  if (patches > 0) {
    fs.writeFileSync(filePath, out.join('\n'));
  }
  return patches;
}

function walk(dir) {
  const out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...walk(p));
    else if (e.isFile() && p.endsWith('.md')) out.push(p);
  }
  return out;
}

let totalPatches = 0;
let touchedFiles = 0;
for (const root of ROOTS) {
  if (!fs.existsSync(root)) continue;
  for (const p of walk(root)) {
    const n = patchFile(p);
    if (n > 0) {
      touchedFiles++;
      totalPatches += n;
    }
  }
}

console.log(`Tagged ${totalPatches} code fence(s) across ${touchedFiles} file(s).`);
