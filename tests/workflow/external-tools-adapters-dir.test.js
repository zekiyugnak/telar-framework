#!/usr/bin/env node
'use strict';

// Regression test for the ADAPTERS_DIR resolution seam in
// scripts/tl-telar-external-tools.sh.
//
// Bug this locks down (shipped in 0.14.0): the generated Codex plugin FLATTENS
// nested orchestration skills — skills/orchestration/external-tools/adapters/
// becomes skills/orchestration-external-tools/adapters/ — but the dispatcher is
// copied verbatim with a hardcoded nested ADAPTERS_DIR, so `health` reported
// "adapter file missing" for every adapter inside the installed plugin even
// though the adapter scripts were present and working.
//
// The fix probes candidate directories and picks the first that actually holds
// adapters (sentinel: _common.sh). This test exercises that resolver via the
// parser-free `resolve-adapters-dir` subcommand, so it needs no yq/jq/PyYAML and
// runs deterministically in CI (which globs tests/**/*.test.js).

const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..', '..');
const DISP = path.join(ROOT, 'scripts', 'tl-telar-external-tools.sh');

// Run `resolve-adapters-dir` with a given CLAUDE_PLUGIN_ROOT and parse the JSON.
function resolve(pluginRoot) {
  const out = execFileSync('bash', [DISP, 'resolve-adapters-dir'], {
    env: { ...process.env, CLAUDE_PLUGIN_ROOT: pluginRoot },
    encoding: 'utf8',
  });
  return JSON.parse(out.trim());
}

// Build a throwaway plugin root that mirrors one packaging layout by dropping a
// stub _common.sh (the sentinel) at the given relative adapters path.
function makePluginRoot(relAdaptersDir) {
  const rootDir = fs.mkdtempSync(path.join(os.tmpdir(), 'tl-adapters-'));
  if (relAdaptersDir) {
    const adaptersDir = path.join(rootDir, relAdaptersDir);
    fs.mkdirSync(adaptersDir, { recursive: true });
    fs.writeFileSync(path.join(adaptersDir, '_common.sh'), '# stub\n');
  }
  return rootDir;
}

const tmpRoots = [];
const synthetic = (rel) => {
  const r = makePluginRoot(rel);
  tmpRoots.push(r);
  return r;
};

try {
  // 1. Canonical nested layout (dev checkout / Telar source) resolves and exists.
  {
    const r = resolve(synthetic('skills/orchestration/external-tools/adapters'));
    assert.equal(r.exists, true, 'nested layout: adapters must resolve as existing');
    assert.ok(
      r.adapters_dir.endsWith('skills/orchestration/external-tools/adapters'),
      `nested layout: unexpected adapters_dir ${r.adapters_dir}`,
    );
  }

  // 2. Generated Codex FLATTENED layout — the exact regression — resolves and exists.
  {
    const r = resolve(synthetic('skills/orchestration-external-tools/adapters'));
    assert.equal(r.exists, true, 'flattened layout: adapters must resolve as existing (the 0.14.0 bug)');
    assert.ok(
      r.adapters_dir.endsWith('skills/orchestration-external-tools/adapters'),
      `flattened layout: unexpected adapters_dir ${r.adapters_dir}`,
    );
  }

  // 3. Generated plugin's carried source subtree — last-resort candidate — resolves.
  {
    const r = resolve(synthetic('source/skills/orchestration/external-tools/adapters'));
    assert.equal(r.exists, true, 'source-subtree layout: adapters must resolve as existing');
    assert.ok(
      r.adapters_dir.endsWith('source/skills/orchestration/external-tools/adapters'),
      `source-subtree layout: unexpected adapters_dir ${r.adapters_dir}`,
    );
  }

  // 4. Priority order: when BOTH nested and flattened exist, canonical nested wins.
  {
    const both = synthetic('skills/orchestration/external-tools/adapters');
    fs.mkdirSync(path.join(both, 'skills/orchestration-external-tools/adapters'), { recursive: true });
    fs.writeFileSync(path.join(both, 'skills/orchestration-external-tools/adapters/_common.sh'), '# stub\n');
    const r = resolve(both);
    assert.ok(
      r.adapters_dir.endsWith('skills/orchestration/external-tools/adapters'),
      `priority: nested must win over flattened, got ${r.adapters_dir}`,
    );
  }

  // 5. Fail-loud contract: no candidate present -> exists:false, and the path is
  //    candidate #1 (canonical nested) so the runtime "adapter file missing"
  //    error still fires with a sensible path instead of silently breaking.
  {
    const r = resolve(synthetic(null));
    assert.equal(r.exists, false, 'empty root: nothing should resolve as existing');
    assert.ok(
      r.adapters_dir.endsWith('skills/orchestration/external-tools/adapters'),
      `empty root: fallback path must be canonical nested, got ${r.adapters_dir}`,
    );
  }

  // 6. Regression against the REAL committed generated plugin artifact: the
  //    dispatcher packaged inside plugins/tl-telar must resolve its own adapters.
  //    Only runs once the generated dispatcher carries the resolve-adapters-dir
  //    subcommand (i.e. after `node scripts/generate-codex-plugin.js` regenerates
  //    it from the fixed source). CI's codex-artifacts-drift job independently
  //    guarantees the generated tree is not stale.
  {
    const genDisp = path.join(ROOT, 'plugins', 'tl-telar', 'scripts', 'tl-telar-external-tools.sh');
    const genRoot = path.join(ROOT, 'plugins', 'tl-telar');
    if (fs.existsSync(genDisp) && fs.readFileSync(genDisp, 'utf8').includes('resolve-adapters-dir')) {
      const out = execFileSync('bash', [genDisp, 'resolve-adapters-dir'], {
        env: { ...process.env, CLAUDE_PLUGIN_ROOT: genRoot },
        encoding: 'utf8',
      });
      const r = JSON.parse(out.trim());
      assert.equal(
        r.exists,
        true,
        'committed generated plugin: its own dispatcher must resolve its adapters',
      );
      assert.ok(
        r.adapters_dir.endsWith('skills/orchestration-external-tools/adapters'),
        `committed generated plugin: expected flattened adapters dir, got ${r.adapters_dir}`,
      );
    } else {
      console.log('  (skipping generated-artifact check — regenerate plugins/tl-telar to enable it)');
    }
  }

  console.log('external-tools-adapters-dir: all assertions passed');
} finally {
  for (const r of tmpRoots) {
    fs.rmSync(r, { recursive: true, force: true });
  }
}
