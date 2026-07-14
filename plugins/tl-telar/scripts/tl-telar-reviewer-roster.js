#!/usr/bin/env node

/**
 * Pure, stack-aware adversarial-reviewer roster resolver for /tl-telar:orchestrate.
 *
 * Phase 2 replaces the mobile-hardcoded roster in
 * skills/orchestration/adversarial-code-review.md with this deterministic,
 * testable resolver (same pattern as tl-telar-wu-scheduler.js).
 *
 * INPUT  : a Work Unit's file_scope (paths) + an optional default domain.
 * OUTPUT : JSON { domains, reviewers: [{ role, reviewer_key, rubric, model, reason }] }
 *
 * The framework is multi-domain (mobile, web, backend/data, rust, desktop) — the
 * reviewer ROLES are generic; only the RUBRIC is domain-specific. Every reviewer
 * runs on Opus (Phase 1 gate-quality decision).
 *
 * Usage:
 *   node scripts/tl-telar-reviewer-roster.js --default-domain web path1 path2 ...
 *   echo '["migrations/x.sql","admin/a.tsx"]' | node scripts/tl-telar-reviewer-roster.js --json
 */

'use strict';

const REVIEWER_MODEL = 'opus';
const RUBRIC_DIR = 'resources/rubrics/orchestration';

// Domain classifiers, checked per path (first match wins for the primary tag,
// but a path may also carry secondary concerns: `ui` and `perf`).
const DOMAIN_RULES = [
  { domain: 'rust',         re: /(^|\/)cargo\.toml$|\.rs$|(^|\/)crates\//i },
  { domain: 'backend-data', re: /(^|\/)migrations?\/|\.sql$|(^|\/)supabase\/|(^|\/)db\//i },
  { domain: 'desktop',      re: /(^|\/)(electron|src-tauri)\/|(^|\/)(main|preload)\.(ts|js)$|electron-builder|forge\.config|tauri\.conf\.json/i },
  { domain: 'mobile',       re: /(^|\/)screens\/|(^|\/)lib\/(widgets|ui)\/|\.dart$|(^|\/)(ios|android)\/|react-native|(^|\/)mobile\//i },
  { domain: 'web',          re: /\.astro$|\.vue$|(^|\/)admin\/|(^|\/)apps\/web\/|(^|\/)src\/app\/|(^|\/)web\//i },
];

const UI_RE   = /\.(tsx|jsx|dart|astro|vue|svelte)$|(^|\/)(components|screens|widgets|pages)\//i;
const PERF_RE = /(list|table|grid|virtual|animation|render|chart|carousel)/i;
const CODE_RE = /\.(ts|tsx|js|jsx|dart|rs|sql|astro|vue|svelte|mjs|cjs)$/i;

// domain -> { security rubric, a11y rubric (UI only), perf rubric (UI only) }
const RUBRICS = {
  mobile: {
    security: 'mobile-security-adversarial-rubric.md',
    a11y: 'mobile-accessibility-adversarial-rubric.md',
    perf: 'mobile-performance-adversarial-rubric.md',
    securityKey: 'mobile-security', a11yKey: 'mobile-a11y', perfKey: 'mobile-perf',
  },
  web: {
    security: 'web-security-adversarial-rubric.md',
    a11y: 'web-accessibility-adversarial-rubric.md',
    perf: 'web-performance-adversarial-rubric.md',
    securityKey: 'web-security', a11yKey: 'web-a11y', perfKey: 'web-perf',
  },
  'backend-data': {
    security: 'backend-data-security-adversarial-rubric.md',
    securityKey: 'backend-data-security',
  },
  rust: {
    security: 'rust-safety-adversarial-rubric.md',
    securityKey: 'rust-safety',
  },
  desktop: {
    security: 'desktop-security-adversarial-rubric.md',
    securityKey: 'desktop-security',
  },
};

const UI_DOMAINS = ['mobile', 'web']; // domains that carry a11y / perf concerns

function classify(paths, defaultDomain) {
  const domains = new Set();
  let hasUI = false;
  let hasPerf = false;
  let hasCode = false;
  const uiDomains = new Set();

  for (const raw of paths) {
    const p = String(raw).trim();
    if (!p) continue;

    let primary = null;
    for (const rule of DOMAIN_RULES) {
      if (rule.re.test(p)) { primary = rule.domain; break; }
    }

    const isUI = UI_RE.test(p);
    if (isUI) hasUI = true;
    if (CODE_RE.test(p)) hasCode = true;

    // A UI file with no strong domain marker inherits the default domain.
    if (!primary && isUI) primary = defaultDomain || null;
    if (primary) domains.add(primary);
    if (isUI && UI_DOMAINS.includes(primary)) uiDomains.add(primary);

    if (isUI && PERF_RE.test(p)) hasPerf = true;
  }

  // If nothing classified at all, fall back to the default domain so a WU is
  // never left with only a generic code review.
  if (domains.size === 0 && defaultDomain) domains.add(defaultDomain);

  return { domains: [...domains], hasUI, hasPerf, hasCode, uiDomains: [...uiDomains] };
}

function resolveRoster(paths, defaultDomain) {
  const { domains, hasUI, hasPerf, hasCode, uiDomains } = classify(paths, defaultDomain);
  const reviewers = [];

  // Always-on: generic adversarial code reviewer.
  reviewers.push({
    role: 'Code',
    reviewer_key: 'code',
    rubric: `${RUBRIC_DIR}/adversarial-review-rubric.md`,
    model: REVIEWER_MODEL,
    reason: 'always-on',
  });

  // Always-on when any code file is in scope: senior Maintainability/Design reviewer.
  if (hasCode) {
    reviewers.push({
      role: 'Maintainability',
      reviewer_key: 'maintainability',
      rubric: `${RUBRIC_DIR}/maintainability-design-adversarial-rubric.md`,
      model: REVIEWER_MODEL,
      reason: 'code-in-scope',
    });
  }

  // Always-on: one Security reviewer per present domain (domain-specific rubric).
  for (const d of domains) {
    const r = RUBRICS[d];
    if (r && r.security) {
      reviewers.push({
        role: 'Security',
        reviewer_key: r.securityKey,
        rubric: `${RUBRIC_DIR}/${r.security}`,
        model: REVIEWER_MODEL,
        reason: `domain:${d}`,
      });
    }
  }

  // Always-on for backend/service work: ONE grouped correctness reviewer covering
  // data-integrity + reliability + API-contract (distinct from the security reviewer).
  if (domains.includes('backend-data') || domains.includes('rust')) {
    reviewers.push({
      role: 'BackendCorrectness',
      reviewer_key: 'backend-correctness',
      rubric: `${RUBRIC_DIR}/backend-correctness-adversarial-rubric.md`,
      model: REVIEWER_MODEL,
      reason: 'backend/service-in-scope',
    });
  }

  // Conditional: Frontend UX completeness + i18n — ONE reviewer when any UI is in
  // scope (rubric is domain-agnostic: states, responsive, localization).
  if (hasUI) {
    reviewers.push({
      role: 'FrontendUX',
      reviewer_key: 'frontend-ux',
      rubric: `${RUBRIC_DIR}/frontend-ux-adversarial-rubric.md`,
      model: REVIEWER_MODEL,
      reason: 'ui-in-scope',
    });
  }

  // Conditional: A11y — one per UI domain in scope.
  if (hasUI) {
    const targets = uiDomains.length ? uiDomains : UI_DOMAINS.filter((d) => domains.includes(d));
    for (const d of targets) {
      const r = RUBRICS[d];
      if (r && r.a11y) {
        reviewers.push({
          role: 'Accessibility',
          reviewer_key: r.a11yKey,
          rubric: `${RUBRIC_DIR}/${r.a11y}`,
          model: REVIEWER_MODEL,
          reason: `ui-in-scope:${d}`,
        });
      }
    }
  }

  // Conditional: Performance — one per UI domain when perf-sensitive paths present.
  if (hasPerf) {
    const targets = uiDomains.length ? uiDomains : UI_DOMAINS.filter((d) => domains.includes(d));
    for (const d of targets) {
      const r = RUBRICS[d];
      if (r && r.perf) {
        reviewers.push({
          role: 'Performance',
          reviewer_key: r.perfKey,
          rubric: `${RUBRIC_DIR}/${r.perf}`,
          model: REVIEWER_MODEL,
          reason: `perf-sensitive:${d}`,
        });
      }
    }
  }

  return { domains, reviewers };
}

function parseArgs(argv) {
  const paths = [];
  let defaultDomain = null;
  let jsonStdin = false;
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--default-domain') { defaultDomain = argv[i + 1]; i += 1; }
    else if (a === '--json') { jsonStdin = true; }
    else { paths.push(a); }
  }
  return { paths, defaultDomain, jsonStdin };
}

function main() {
  const { paths, defaultDomain, jsonStdin } = parseArgs(process.argv.slice(2));

  const finish = (allPaths) => {
    const out = resolveRoster(allPaths, defaultDomain);
    process.stdout.write(`${JSON.stringify(out, null, 2)}\n`);
  };

  if (jsonStdin) {
    let buf = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (c) => { buf += c; });
    process.stdin.on('end', () => {
      let arr = [];
      try { arr = JSON.parse(buf); } catch (e) { arr = []; }
      finish([...paths, ...(Array.isArray(arr) ? arr : [])]);
    });
  } else {
    finish(paths);
  }
}

// Export for unit tests; run as CLI when invoked directly.
module.exports = { resolveRoster, classify };
if (require.main === module) main();
