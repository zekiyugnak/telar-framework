#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const { resolveRoster } = require('../../scripts/tl-telar-reviewer-roster');

const keys = (r) => r.reviewers.map((x) => x.reviewer_key);

// Web/admin WU: web security + frontend-ux + web a11y; NEVER a mobile rubric.
{
  const r = resolveRoster(['admin/features/dsar/Panel.tsx', 'admin/locales/tr.json'], 'web');
  const k = keys(r);
  assert.ok(k.includes('code'));
  assert.ok(k.includes('web-security'));
  assert.ok(k.includes('frontend-ux'));
  assert.ok(k.includes('web-a11y'));
  assert.ok(!k.some((x) => x.startsWith('mobile')), 'web WU must not get any mobile reviewer');
}

// Backend/migration WU: data-layer security + grouped backend correctness; no UI reviewers.
{
  const r = resolveRoster(['migrations/20260706.sql'], null);
  const k = keys(r);
  assert.deepEqual(k, ['code', 'maintainability', 'backend-data-security', 'backend-correctness']);
  assert.ok(!k.includes('web-a11y') && !k.includes('frontend-ux'));
}

// Rust service WU: rust safety + backend correctness.
{
  const r = resolveRoster(['crates/api/src/handler.rs'], null);
  assert.deepEqual(keys(r), ['code', 'maintainability', 'rust-safety', 'backend-correctness']);
}

// Mobile screen WU: mobile security + frontend-ux + mobile a11y; NEVER a web rubric.
{
  const r = resolveRoster(['screens/Login.tsx'], 'mobile');
  const k = keys(r);
  assert.ok(k.includes('mobile-security') && k.includes('mobile-a11y'));
  assert.ok(!k.some((x) => x.startsWith('web')), 'mobile WU must not get any web reviewer');
}

// Mixed backend + web WU: both security lenses + backend correctness + frontend-ux.
{
  const r = resolveRoster(['migrations/x.sql', 'admin/EmployerList.tsx'], 'web');
  const k = keys(r);
  for (const need of ['backend-data-security', 'web-security', 'backend-correctness', 'frontend-ux', 'web-a11y']) {
    assert.ok(k.includes(need), `mixed WU should include ${need}`);
  }
}

// Perf-sensitive web path activates the web performance reviewer.
{
  const r = resolveRoster(['admin/UsersTable.tsx'], 'web');
  assert.ok(keys(r).includes('web-perf'), 'a *Table* path should trigger web-perf');
}

// Every reviewer runs on Opus (Phase 1 gate-quality pin).
{
  const r = resolveRoster(['migrations/x.sql', 'admin/UsersTable.tsx'], 'web');
  assert.ok(r.reviewers.every((x) => x.model === 'opus'), 'all reviewers must be opus');
}

// Desktop (Electron/Tauri) WU: desktop-security lens.
{
  const r = resolveRoster(['electron/main.ts', 'electron/preload.ts'], null);
  const k = keys(r);
  assert.ok(k.includes('code') && k.includes('desktop-security'));
}
// Tauri WU (rust backend + tauri config): rust safety + backend correctness + desktop security.
{
  const r = resolveRoster(['src-tauri/src/main.rs', 'src-tauri/tauri.conf.json'], null);
  const k = keys(r);
  assert.ok(k.includes('rust-safety') && k.includes('backend-correctness') && k.includes('desktop-security'));
}

// Every emitted reviewer points at a rubric under the orchestration rubric dir.
{
  const r = resolveRoster(['admin/Foo.tsx'], 'web');
  assert.ok(r.reviewers.every((x) => /^resources\/rubrics\/orchestration\/.+\.md$/.test(x.rubric)));
}

// Maintainability reviewer is always-on when any code file is in scope; absent otherwise.
{
  const withCode = resolveRoster(['src/components/Button.tsx'], 'web');
  assert.ok(keys(withCode).includes('maintainability'), 'code WU must include the maintainability reviewer');
  assert.ok(withCode.reviewers.find((x) => x.reviewer_key === 'maintainability').rubric
    === 'resources/rubrics/orchestration/maintainability-design-adversarial-rubric.md');
  const noCode = resolveRoster(['README.md', 'docs/logo.png'], null);
  assert.ok(!keys(noCode).includes('maintainability'), 'non-code WU must not include the maintainability reviewer');
}

console.log('reviewer-roster.test.js: all assertions passed');
