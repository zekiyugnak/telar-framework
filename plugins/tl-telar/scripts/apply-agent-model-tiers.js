#!/usr/bin/env node

/**
 * Phase 1 (model tiering): inject a `model:` field into each agent's frontmatter.
 *
 * This script is the single source of truth for the agent→tier policy. Claude
 * Code reads `model:` from agent frontmatter natively when spawning a named
 * subagent, so the frontmatter IS the runtime signal; this script keeps the
 * 41 assignments consistent and re-appliable (idempotent).
 *
 * Policy (balanced, default Sonnet):
 *   - opus:   deep architecture / adversarial / security / backend reasoning
 *   - haiku:  clearly-mechanical roles (dedup / tagging)
 *   - sonnet: everything else (default)
 *
 * NOTE on `orchestrator`: it is adopted by the main session, never spawned
 * as a subagent, so its frontmatter `model:` is DOCUMENTARY only — the session's
 * `/model` governs its turns. It is tagged opus here to record intent.
 */

const fs = require('fs');
const path = require('path');

const AGENTS_DIR = path.resolve(__dirname, '..', 'agents');

const OPUS = new Set([
  'architect-adversarial',
  'mobile-security-architect',
  'mobile-backend-architect',
  'rust-service-architect',
  'admin-panel-architect',
  'web-security-architect',
  'orchestrator', // documentary — session-governed at runtime
]);

const HAIKU = new Set([
  'knowledge-curator',
]);

const VALID = new Set(['opus', 'sonnet', 'haiku']);

function tierFor(name) {
  if (OPUS.has(name)) return 'opus';
  if (HAIKU.has(name)) return 'haiku';
  return 'sonnet';
}

function main() {
  const files = fs
    .readdirSync(AGENTS_DIR)
    .filter((f) => f.endsWith('.md') && !f.startsWith('_'))
    .sort();

  let changed = 0;
  let already = 0;
  const dist = { opus: 0, sonnet: 0, haiku: 0 };

  for (const file of files) {
    const full = path.join(AGENTS_DIR, file);
    const name = path.basename(file, '.md');
    const tier = tierFor(name);
    dist[tier] += 1;

    const lines = fs.readFileSync(full, 'utf8').split('\n');

    if (lines[0] !== '---') {
      throw new Error(`${file}: expected frontmatter opening '---' on line 1`);
    }

    // Locate frontmatter bounds and any existing model: line.
    let fmEnd = -1;
    let modelIdx = -1;
    let idIdx = -1;
    for (let i = 1; i < lines.length; i += 1) {
      if (lines[i] === '---') { fmEnd = i; break; }
      if (idIdx === -1 && /^id:/.test(lines[i])) idIdx = i;
      if (modelIdx === -1 && /^model:/.test(lines[i])) modelIdx = i;
    }
    if (fmEnd === -1) throw new Error(`${file}: unterminated frontmatter`);
    if (idIdx === -1) throw new Error(`${file}: no 'id:' key in frontmatter`);

    if (modelIdx !== -1) {
      const current = lines[modelIdx].replace(/^model:\s*/, '').trim();
      if (!VALID.has(current)) {
        throw new Error(`${file}: existing model '${current}' is not a valid tier`);
      }
      if (current !== tier) {
        lines[modelIdx] = `model: ${tier}`;
        fs.writeFileSync(full, lines.join('\n'));
        changed += 1;
      } else {
        already += 1;
      }
      continue;
    }

    // Insert `model: <tier>` immediately after the id: line.
    lines.splice(idIdx + 1, 0, `model: ${tier}`);
    fs.writeFileSync(full, lines.join('\n'));
    changed += 1;
  }

  console.log(`Agents processed: ${files.length}`);
  console.log(`  written: ${changed}, already-correct: ${already}`);
  console.log(`  tiers -> opus: ${dist.opus}, sonnet: ${dist.sonnet}, haiku: ${dist.haiku}`);
}

main();
