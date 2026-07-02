#!/usr/bin/env node
'use strict';

const FX_HEADING_RE = /^###\s+(F-\d+):\s*(.*)$/;
const DELTA_HEADER_RE = /^<!--\s*tl-telar-spec-delta:\s*domain=(\S+)\s+baseline-hash=(\S+)\s*-->\s*$/m;
const SECTION_RE = /^##\s+(ADDED|MODIFIED|REMOVED)\s+Requirements\s*$/;

function parseDeltaHeader(deltaContent) {
  const m = deltaContent.match(DELTA_HEADER_RE);
  if (!m) {
    throw new Error(
      'Delta file missing required header comment: <!-- tl-telar-spec-delta: domain=<domain> baseline-hash=<hash> -->'
    );
  }
  return { domain: m[1], baselineHash: m[2] };
}

// Splits a truth REQUIREMENTS.md into: everything before the first F-x
// heading (preamble), and a Map of F-id -> { bodyLines } for everything
// from that heading up to (not including) the next F-x heading.
function splitIntoBlocks(markdown) {
  const lines = markdown.split('\n');
  const blocks = new Map();
  const order = [];
  const preambleLines = [];
  let currentId = null;

  for (const line of lines) {
    const m = line.match(FX_HEADING_RE);
    if (m) {
      currentId = m[1];
      order.push(currentId);
      blocks.set(currentId, { bodyLines: [line] });
      continue;
    }
    if (currentId) {
      blocks.get(currentId).bodyLines.push(line);
    } else {
      preambleLines.push(line);
    }
  }
  return { preamble: preambleLines.join('\n'), blocks, order };
}

// Splits a delta file into { ADDED: [...], MODIFIED: [...], REMOVED: [...] },
// each entry { id, raw }.
function parseDeltaSections(deltaContent) {
  const sections = { ADDED: [], MODIFIED: [], REMOVED: [] };
  const lines = deltaContent.split('\n');
  let currentSection = null;
  let currentId = null;
  let currentLines = null;

  function flush() {
    if (currentSection && currentId) {
      sections[currentSection].push({ id: currentId, raw: currentLines.join('\n') });
    }
  }

  for (const line of lines) {
    const sectionMatch = line.match(SECTION_RE);
    if (sectionMatch) {
      flush();
      currentSection = sectionMatch[1];
      currentId = null;
      currentLines = null;
      continue;
    }
    const fxMatch = line.match(FX_HEADING_RE);
    if (fxMatch && currentSection) {
      flush();
      currentId = fxMatch[1];
      currentLines = [line];
      continue;
    }
    if (currentLines) currentLines.push(line);
  }
  flush();
  return sections;
}

function mergeDelta({ truthContent, deltaContent }) {
  const { preamble, blocks, order } = splitIntoBlocks(truthContent || '');
  const delta = parseDeltaSections(deltaContent);
  const conflicts = [];

  for (const item of delta.ADDED) {
    if (blocks.has(item.id)) {
      conflicts.push(`ADDED ${item.id} already exists in truth — cannot add duplicate`);
      continue;
    }
    blocks.set(item.id, { bodyLines: item.raw.split('\n') });
    order.push(item.id);
  }

  for (const item of delta.MODIFIED) {
    if (!blocks.has(item.id)) {
      conflicts.push(`MODIFIED ${item.id} not found in truth — cannot modify missing requirement`);
      continue;
    }
    blocks.set(item.id, { bodyLines: item.raw.split('\n') });
  }

  for (const item of delta.REMOVED) {
    if (!blocks.has(item.id)) {
      conflicts.push(`REMOVED ${item.id} not found in truth — cannot remove missing requirement`);
      continue;
    }
    const existing = blocks.get(item.id);
    const [heading, ...rest] = existing.bodyLines;
    blocks.set(item.id, { bodyLines: [heading, '**Status:** deprecated', ...rest] });
  }

  if (conflicts.length > 0) {
    return { mergedContent: null, conflicts };
  }

  const bodyText = order.map((id) => blocks.get(id).bodyLines.join('\n')).join('\n');
  const mergedContent = `${preamble}${preamble.endsWith('\n') ? '' : '\n'}${bodyText}\n`;
  return { mergedContent, conflicts: [] };
}

module.exports = { mergeDelta, splitIntoBlocks, parseDeltaSections, parseDeltaHeader };
