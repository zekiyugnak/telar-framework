#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const { resolveRoster } = require('../../scripts/tl-telar-reviewer-roster');

const keys = (r) => r.reviewers.map((x) => x.reviewer_key);
const crit = (paths, dd) => resolveRoster(paths, dd, { riskTier: 'critical' });
const std = (paths, dd) => resolveRoster(paths, dd, { riskTier: 'standard' });
const triv = (paths, dd) => resolveRoster(paths, dd, { riskTier: 'trivial' });

// ============================================================================
// CRITICAL tier == the historical "full roster". Domain routing still holds:
// the correct rubric per stack, never a cross-stack rubric.
// ============================================================================

// Web/admin WU (critical): web security + frontend-ux + web a11y; NEVER a mobile rubric.
{
  const k = keys(crit(['admin/features/dsar/Panel.tsx', 'admin/locales/tr.json'], 'web'));
  assert.ok(k.includes('code'));
  assert.ok(k.includes('web-security'));
  assert.ok(k.includes('frontend-ux'));
  assert.ok(k.includes('web-a11y'));
  assert.ok(!k.some((x) => x.startsWith('mobile')), 'web WU must not get any mobile reviewer');
}

// Mobile screen WU (critical): mobile security + frontend-ux + mobile a11y; NEVER a web rubric.
{
  const k = keys(crit(['screens/Home.tsx'], 'mobile'));
  assert.ok(k.includes('mobile-security') && k.includes('mobile-a11y'));
  assert.ok(!k.some((x) => x.startsWith('web')), 'mobile WU must not get any web reviewer');
}

// Mixed backend + web WU (critical): both security lenses + backend correctness + frontend-ux.
{
  const k = keys(crit(['migrations/x.sql', 'admin/EmployerList.tsx'], 'web'));
  for (const need of ['backend-data-security', 'web-security', 'backend-correctness', 'frontend-ux', 'web-a11y']) {
    assert.ok(k.includes(need), `mixed critical WU should include ${need}`);
  }
}

// Perf-sensitive web path (critical) activates the web performance reviewer.
{
  assert.ok(keys(crit(['admin/UsersTable.tsx'], 'web')).includes('web-perf'), 'a *Table* path should trigger web-perf at critical');
}

// Desktop (Electron/Tauri) WU (critical): desktop-security lens.
{
  const k = keys(crit(['electron/main.ts', 'electron/preload.ts'], null));
  assert.ok(k.includes('code') && k.includes('desktop-security'));
}

// Tauri WU (critical): rust safety + backend correctness + desktop security.
{
  const k = keys(crit(['src-tauri/src/main.rs', 'src-tauri/tauri.conf.json'], null));
  assert.ok(k.includes('rust-safety') && k.includes('backend-correctness') && k.includes('desktop-security'));
}

// ============================================================================
// STANDARD tier (the default) is LIGHT: Code + Maintainability + (backend/sensitive)
// Security + BackendCorrectness. UI specialists (frontend-ux / a11y / perf) are NOT
// spawned — their mechanical criteria move to the Katman-1 CI lenses.
// ============================================================================

// Pure (non-sensitive) UI at standard: just code + maintainability. No UI specialists.
{
  const k = keys(std(['admin/features/dsar/Panel.tsx', 'admin/locales/tr.json'], 'web'));
  assert.deepEqual(k, ['code', 'maintainability']);
  assert.ok(!k.includes('web-security') && !k.includes('frontend-ux') && !k.includes('web-a11y'));
}

// Perf-sensitive UI at standard does NOT spawn the perf LLM reviewer (CI budget covers it).
{
  assert.ok(!keys(std(['admin/UsersTable.tsx'], 'web')).includes('web-perf'), 'standard must not spawn web-perf');
}

// Backend migration at standard is UNCHANGED from the historical roster (backend is
// high-stakes AND .sql trips the sensitive floor): security + backend correctness stay.
{
  assert.deepEqual(keys(std(['migrations/20260706.sql'], null)),
    ['code', 'maintainability', 'backend-data-security', 'backend-correctness']);
}

// Rust service at standard: rust safety + backend correctness (high-stakes domain).
{
  assert.deepEqual(keys(std(['crates/api/src/handler.rs'], null)),
    ['code', 'maintainability', 'rust-safety', 'backend-correctness']);
}

// Desktop at standard keeps its security lens (high-stakes domain).
{
  assert.ok(keys(std(['electron/main.ts'], null)).includes('desktop-security'));
}

// Default call (no riskTier) === standard.
{
  assert.deepEqual(keys(resolveRoster(['admin/features/dsar/Panel.tsx'], 'web')), ['code', 'maintainability']);
}

// ============================================================================
// TRIVIAL tier: Code only — plus the security floor when a sensitive path is present.
// ============================================================================

// Trivial non-sensitive UI: code only.
{
  assert.deepEqual(keys(triv(['admin/features/dsar/Panel.tsx'], 'web')), ['code']);
}

// Trivial doc/config: code only (no maintainability, it's below standard).
{
  assert.deepEqual(keys(triv(['README.md'], null)), ['code']);
}

// ============================================================================
// SENSITIVE-PATH FLOOR: a Security reviewer is FORCED on EVERY tier, never
// droppable — even trivial. This is the "small diff to critical code" guardrail.
// ============================================================================

// UI touching auth: web-security present at trivial AND standard (floor overrides tier).
{
  assert.ok(keys(triv(['admin/features/auth/Login.tsx'], 'web')).includes('web-security'),
    'trivial auth WU must still get security (floor)');
  assert.ok(keys(std(['admin/features/auth/Login.tsx'], 'web')).includes('web-security'),
    'standard auth WU must get security (floor)');
}

// A variety of sensitive tokens each trip the floor even on a trivial pure-UI WU.
for (const p of ['src/lib/token-store.ts', 'src/PaymentForm.tsx', 'src/hooks/useSession.ts', 'src/crypto/hash.ts']) {
  const k = keys(triv([p], 'web'));
  assert.ok(k.some((x) => x.endsWith('security')), `sensitive path ${p} must force a security reviewer at trivial`);
}

// A mobile login screen is inherently sensitive → security even at standard.
{
  assert.ok(keys(std(['screens/Login.tsx'], 'mobile')).includes('mobile-security'),
    'a login screen trips the sensitive floor');
}

// A plainly non-sensitive filename does NOT trip the floor at standard.
{
  assert.ok(!keys(std(['src/components/Button.tsx'], 'web')).includes('web-security'),
    'a plain Button component is not sensitive');
}

// ============================================================================
// INVARIANTS (tier-independent).
// ============================================================================

// risk_tier is echoed back; unknown tiers normalize to standard.
{
  assert.equal(crit(['admin/Foo.tsx'], 'web').risk_tier, 'critical');
  assert.equal(std(['admin/Foo.tsx'], 'web').risk_tier, 'standard');
  assert.equal(resolveRoster(['admin/Foo.tsx'], 'web', { riskTier: 'bogus' }).risk_tier, 'standard');
  assert.equal(resolveRoster(['admin/Foo.tsx'], 'web').risk_tier, 'standard');
}

// Every reviewer runs on Opus (Phase 1 gate-quality pin) — across tiers.
{
  const r = crit(['migrations/x.sql', 'admin/UsersTable.tsx'], 'web');
  assert.ok(r.reviewers.every((x) => x.model === 'opus'), 'all reviewers must be opus');
}

// Every emitted reviewer points at a rubric under the orchestration rubric dir.
{
  const r = crit(['admin/Foo.tsx'], 'web');
  assert.ok(r.reviewers.every((x) => /^resources\/rubrics\/orchestration\/.+\.md$/.test(x.rubric)));
}

// Maintainability present iff code in scope (at standard/critical); the rubric is stable.
{
  const withCode = std(['src/components/Button.tsx'], 'web');
  assert.ok(keys(withCode).includes('maintainability'), 'code WU must include the maintainability reviewer');
  assert.ok(withCode.reviewers.find((x) => x.reviewer_key === 'maintainability').rubric
    === 'resources/rubrics/orchestration/maintainability-design-adversarial-rubric.md');
  assert.ok(!keys(std(['README.md', 'docs/logo.png'], null)).includes('maintainability'),
    'non-code WU must not include the maintainability reviewer');
}

console.log('reviewer-roster.test.js: all assertions passed');
