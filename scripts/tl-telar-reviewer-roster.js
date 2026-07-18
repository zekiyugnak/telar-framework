#!/usr/bin/env node

/**
 * Pure, stack-aware adversarial-reviewer roster resolver for /tl-telar:orchestrate.
 *
 * Phase 2 replaces the mobile-hardcoded roster in
 * skills/orchestration/adversarial-code-review.md with this deterministic,
 * testable resolver (same pattern as tl-telar-wu-scheduler.js).
 *
 * INPUT  : a Work Unit's file_scope (paths) + an optional default domain + risk_tier.
 * OUTPUT : JSON { risk_tier, domains, reviewers: [{ role, reviewer_key, rubric, model, reason }] }
 *
 * The framework is multi-domain (mobile, web, backend/data, rust, desktop) — the
 * reviewer ROLES are generic; only the RUBRIC is domain-specific. Every reviewer
 * runs on the configured reviewer model (default Opus; from routing.roles.reviewer
 * via --model, a Phase 1 gate-quality decision).
 *
 * The roster SIZE scales with the WU's risk_tier (trivial|standard|critical, default
 * standard) — see the tier policy above resolveRoster(). Standard is the light default
 * (UI a11y/perf/ux are handled by CI, not LLM reviewers); critical spawns the full roster.
 * A Security reviewer is FORCED on every tier when a sensitive path is in scope (the floor).
 *
 * Usage:
 *   node scripts/tl-telar-reviewer-roster.js --default-domain web --risk-tier standard path1 path2 ...
 *   echo '["migrations/x.sql","admin/a.tsx"]' | node scripts/tl-telar-reviewer-roster.js --risk-tier critical --json
 */

'use strict';

// Default Claude reviewer tier. Overridable via --model (or opts.reviewerModel):
// the orchestrator resolves routing.roles.reviewer with
// `tl-telar-external-tools.sh resolve-role reviewer` and passes the first
// claude-exec model's tier here (keeping this resolver pure — no YAML I/O).
const DEFAULT_REVIEWER_MODEL = 'opus';
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

// Security FLOOR: a path touching one of these surfaces is inherently sensitive.
// When ANY in-scope path matches, a Security reviewer is forced on EVERY tier —
// the floor is never droppable by risk_tier (a "trivial"-tagged auth change still
// gets Security). Matched on word boundaries against a camelCase-split form of the
// path (so `PaymentForm`, `useSession`, `AuthProvider` all trip it) while avoiding
// over-matching (`author` does NOT match `auth`; `oracle` does NOT match `acl`).
const SENSITIVE_RE =
  /\b(auth|oauth|authz|authn|session|login|signup|signin|token|jwt|password|passwd|secret|credential|crypto|encrypt|cipher|payment|billing|invoice|charge|migrations?|rls|acl|access[ _-]?control)\b|\.sql$/i;

// Split camelCase / PascalCase so `PaymentForm` → `Payment Form`, exposing word
// boundaries the sensitive matcher can anchor on.
function camelSplit(s) {
  return String(s).replace(/([a-z0-9])([A-Z])/g, '$1 $2');
}

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
  let hasSensitive = false;
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
    if (SENSITIVE_RE.test(camelSplit(p))) hasSensitive = true;

    // A UI file with no strong domain marker inherits the default domain.
    if (!primary && isUI) primary = defaultDomain || null;
    if (primary) domains.add(primary);
    if (isUI && UI_DOMAINS.includes(primary)) uiDomains.add(primary);

    if (isUI && PERF_RE.test(p)) hasPerf = true;
  }

  // If nothing classified at all, fall back to the default domain so a WU is
  // never left with only a generic code review.
  if (domains.size === 0 && defaultDomain) domains.add(defaultDomain);

  return { domains: [...domains], hasUI, hasPerf, hasCode, hasSensitive, uiDomains: [...uiDomains] };
}

// Risk-tier policy (see the `review` block in tl-telar-thresholds.json):
//   trivial  → Code only  (+ Security ONLY when the sensitive-path FLOOR fires).
//   standard → Code + Maintainability + Security(floor OR high-stakes backend/rust/desktop
//              domain) + BackendCorrectness. UI specialists (FrontendUX / Accessibility /
//              Performance) are NOT spawned as LLM reviewers — their mechanical criteria are
//              covered by the Katman-1 CI lenses (axe, perf-budget, lint). Bump a UI-heavy WU
//              to `critical` when you want LLM UX/a11y/perf judgment.
//   critical → the FULL roster (every relevant domain reviewer). The qualitative escalations
//              (design-gate up front, human checkpoint, strict CI, non-sticky security retry)
//              live in the skills, not here.
// The Security FLOOR (a sensitive path in scope) is NEVER droppable by tier.
const TIERS = new Set(['trivial', 'standard', 'critical']);
const HIGH_STAKES_DOMAINS = ['backend-data', 'rust', 'desktop'];

function normalizeTier(t) {
  const v = String(t == null ? 'standard' : t).toLowerCase();
  return TIERS.has(v) ? v : 'standard';
}

// One Security reviewer per given domain (domain-specific rubric).
function securityReviewersFor(domains, reviewerModel) {
  const out = [];
  for (const d of domains) {
    const r = RUBRICS[d];
    if (r && r.security) {
      out.push({
        role: 'Security',
        reviewer_key: r.securityKey,
        rubric: `${RUBRIC_DIR}/${r.security}`,
        model: reviewerModel,
        reason: `domain:${d}`,
      });
    }
  }
  return out;
}

function resolveRoster(paths, defaultDomain, opts = {}) {
  const riskTier = normalizeTier(opts.riskTier);
  const reviewerModel = opts.reviewerModel || DEFAULT_REVIEWER_MODEL;
  const { domains, hasUI, hasPerf, hasCode, hasSensitive, uiDomains } = classify(paths, defaultDomain);
  const reviewers = [];

  // Always-on: generic adversarial code reviewer.
  reviewers.push({
    role: 'Code',
    reviewer_key: 'code',
    rubric: `${RUBRIC_DIR}/adversarial-review-rubric.md`,
    model: reviewerModel,
    reason: 'always-on',
  });

  // --- trivial: Code + the security floor only ------------------------------
  if (riskTier === 'trivial') {
    if (hasSensitive) reviewers.push(...securityReviewersFor(domains, reviewerModel));
    return { risk_tier: riskTier, domains, reviewers };
  }

  // --- standard & critical --------------------------------------------------
  // Senior Maintainability/Design reviewer whenever code is in scope (advisory).
  if (hasCode) {
    reviewers.push({
      role: 'Maintainability',
      reviewer_key: 'maintainability',
      rubric: `${RUBRIC_DIR}/maintainability-design-adversarial-rubric.md`,
      model: reviewerModel,
      reason: 'code-in-scope',
    });
  }

  // Security: critical → every in-scope domain; standard → only when the floor fires
  // OR the domain is inherently high-stakes (backend-data / rust / desktop).
  const securityDomains = riskTier === 'critical'
    ? domains
    : domains.filter((d) => hasSensitive || HIGH_STAKES_DOMAINS.includes(d));
  reviewers.push(...securityReviewersFor(securityDomains, reviewerModel));

  // Backend/service work: ONE grouped correctness reviewer (data-integrity + reliability
  // + API-contract), distinct from the security reviewer. On both standard and critical.
  if (domains.includes('backend-data') || domains.includes('rust')) {
    reviewers.push({
      role: 'BackendCorrectness',
      reviewer_key: 'backend-correctness',
      rubric: `${RUBRIC_DIR}/backend-correctness-adversarial-rubric.md`,
      model: reviewerModel,
      reason: 'backend/service-in-scope',
    });
  }

  // UI specialists are CRITICAL-only as LLM reviewers (standard relies on CI lenses).
  if (riskTier === 'critical' && hasUI) {
    // Frontend UX completeness + i18n — ONE reviewer (states, responsive, localization).
    reviewers.push({
      role: 'FrontendUX',
      reviewer_key: 'frontend-ux',
      rubric: `${RUBRIC_DIR}/frontend-ux-adversarial-rubric.md`,
      model: reviewerModel,
      reason: 'ui-in-scope',
    });
    // A11y — one per UI domain in scope.
    const a11yTargets = uiDomains.length ? uiDomains : UI_DOMAINS.filter((d) => domains.includes(d));
    for (const d of a11yTargets) {
      const r = RUBRICS[d];
      if (r && r.a11y) {
        reviewers.push({
          role: 'Accessibility',
          reviewer_key: r.a11yKey,
          rubric: `${RUBRIC_DIR}/${r.a11y}`,
          model: reviewerModel,
          reason: `ui-in-scope:${d}`,
        });
      }
    }
  }

  // Performance — CRITICAL-only, one per UI domain when perf-sensitive paths present.
  if (riskTier === 'critical' && hasPerf) {
    const perfTargets = uiDomains.length ? uiDomains : UI_DOMAINS.filter((d) => domains.includes(d));
    for (const d of perfTargets) {
      const r = RUBRICS[d];
      if (r && r.perf) {
        reviewers.push({
          role: 'Performance',
          reviewer_key: r.perfKey,
          rubric: `${RUBRIC_DIR}/${r.perf}`,
          model: reviewerModel,
          reason: `perf-sensitive:${d}`,
        });
      }
    }
  }

  return { risk_tier: riskTier, domains, reviewers };
}

function parseArgs(argv) {
  const paths = [];
  let defaultDomain = null;
  let riskTier = 'standard';
  let reviewerModel = null;
  let jsonStdin = false;
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--default-domain') { defaultDomain = argv[i + 1]; i += 1; }
    else if (a === '--risk-tier') { riskTier = argv[i + 1]; i += 1; }
    else if (a === '--model' || a === '--reviewer-model') { reviewerModel = argv[i + 1]; i += 1; }
    else if (a === '--json') { jsonStdin = true; }
    else { paths.push(a); }
  }
  return { paths, defaultDomain, riskTier, reviewerModel, jsonStdin };
}

function main() {
  const { paths, defaultDomain, riskTier, reviewerModel, jsonStdin } = parseArgs(process.argv.slice(2));

  const finish = (allPaths) => {
    const out = resolveRoster(allPaths, defaultDomain, { riskTier, reviewerModel });
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
