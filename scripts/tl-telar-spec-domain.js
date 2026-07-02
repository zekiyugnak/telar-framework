#!/usr/bin/env node
'use strict';

// Folders that describe a technical LAYER, not a feature DOMAIN. Skipped
// when scanning a path for a domain candidate — see inferDomain below.
const SKIP_SEGMENTS = new Set([
  'src', 'lib', 'app', 'screens', 'features', 'modules', 'components',
  'pages', 'api', 'services', 'utils', 'hooks', 'store', 'redux',
  'context', 'containers', 'views', '__tests__', 'test', 'tests',
]);

function stripExtension(segment) {
  return segment.replace(/\.(tsx?|jsx?|dart|swift|kt|test\.tsx?|test\.jsx?)$/i, '');
}

// Returns the first path segment that is NOT a known layer folder, or null
// if every segment is a layer folder (e.g. 'src/lib/app').
function candidateFor(filePath) {
  const segments = filePath.split('/').filter(Boolean);
  for (const segment of segments) {
    const lower = segment.toLowerCase();
    if (SKIP_SEGMENTS.has(lower)) continue;
    const stripped = stripExtension(lower);
    if (!/^[a-z0-9][a-z0-9_-]*$/.test(stripped)) continue;
    return stripped;
  }
  return null;
}

// Domain assignment is a heuristic, always confirmed/overridden by the user
// at proposal time (see skills/requirements-gather.md Step 0) — it does not
// need to be perfect, only a good first guess.
function inferDomain(filePaths) {
  const counts = new Map();
  for (const filePath of filePaths) {
    const candidate = candidateFor(filePath);
    if (!candidate) continue;
    counts.set(candidate, (counts.get(candidate) || 0) + 1);
  }
  if (counts.size === 0) return null;
  let best = null;
  let bestCount = -1;
  for (const [domain, count] of counts) {
    if (count > bestCount) {
      best = domain;
      bestCount = count;
    }
  }
  return best;
}

module.exports = { inferDomain };
