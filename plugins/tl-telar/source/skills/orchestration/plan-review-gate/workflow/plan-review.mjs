export const meta = {
  name: 'plan-review-gate',
  description: 'Adversarial 3-reviewer gate on a plan; overall PASS iff all 3 reviewers PASS. Deterministic accelerator for skills/orchestration/plan-review-gate — returns the exact aggregated verdict object the prose gate produces.',
  phases: [
    { title: 'Review', detail: 'Spawn Feasibility / Completeness / Scope-Alignment reviewers in parallel (fresh, isolated)' },
    { title: 'Aggregate', detail: 'Any-FAIL aggregation; PASS iff all three PASS' },
  ],
}

// ---------------------------------------------------------------------------
// Contract parity: this workflow is an ACCELERATOR, not a new contract. It MUST
// return the identical aggregated object the prose gate emits (see
// ../SKILL.md Step 3 and ../references/verdict-schema.md "Aggregation"):
//   { overall_verdict, iteration, blocking_reviewers, all_blockers,
//     all_advisories, max_iterations_reached }
// The per-reviewer schema below mirrors ../references/verdict-schema.md exactly.
// The reviewer prompts are copied verbatim from ../references/reviewer-prompts.md
// (kept in sync — that file remains the single source of truth for both paths).
// ---------------------------------------------------------------------------

const ROLES = ['feasibility', 'completeness', 'scope-alignment']

const FINDING_SCHEMA = {
  type: 'object',
  required: ['rule', 'summary', 'evidence'],
  additionalProperties: false,
  properties: {
    rule: { type: 'string', description: 'Rubric rule ID (e.g. A3, B1, C2) or M1-M4 for advisories.' },
    summary: { type: 'string', description: 'One-sentence finding.' },
    evidence: {
      type: 'array',
      items: {
        type: 'object',
        required: ['file', 'line', 'snippet'],
        additionalProperties: false,
        properties: {
          file: { type: 'string' },
          line: { type: 'integer' },
          snippet: { type: 'string' },
        },
      },
    },
    // Required for blockers, optional for advisories, <=300 chars. Kept open
    // as free text so adversarial reasoning is not flattened by the schema.
    explanation: { type: 'string' },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['reviewer', 'iteration', 'verdict', 'blockers', 'advisories', 'reviewed_files'],
  additionalProperties: false,
  properties: {
    reviewer: { enum: ROLES },
    iteration: { type: 'integer', minimum: 1 },
    verdict: { enum: ['PASS', 'FAIL'] },
    blockers: { type: 'array', items: FINDING_SCHEMA },
    advisories: { type: 'array', items: FINDING_SCHEMA },
    reviewed_files: { type: 'array', items: { type: 'string' } },
  },
}

// Verbatim from ../references/reviewer-prompts.md. Only the {{...}} slots differ.
function reviewerPrompt(role, planText, userRequest, iteration) {
  const header = {
    feasibility: `You are the FEASIBILITY REVIEWER of a software implementation plan.

Mode: Adversarial. Your job is to FIND FAILURES, not to approve, not to suggest
improvements. Either the plan is physically executable on this codebase or it
is not.

You have NO context from previous reviews. Judge fresh.

Read \`resources/rubrics/orchestration/plan-review-rubric-adversarial.md\`
section A (Feasibility) and apply criteria A1-A6.

Apply the mobile-specific advisories M1-M4 only as \`advisories\` (never as
blockers). Specifically: if the plan references \`.tl-telar-thresholds.json\`
thresholds but that file does not exist in the repo, flag M4 as an advisory.
Do NOT fail the plan for missing thresholds.`,
    completeness: `You are the COMPLETENESS REVIEWER of a software implementation plan.

Mode: Adversarial. Your job is to FIND FAILURES, not to approve, not to suggest
improvements. Either the plan covers everything the user asked for and every
referenced requirement, or it does not.

You have NO context from previous reviews. Judge fresh.

Read \`resources/rubrics/orchestration/plan-review-rubric-adversarial.md\`
section B (Completeness) and apply criteria B1-B6. If \`REQUIREMENTS.md\` exists
in the repo, check that every F-x / UI-x identifier the plan claims to satisfy
actually maps to a concrete task.

Apply mobile advisories M1-M4 only as \`advisories\`.`,
    'scope-alignment': `You are the SCOPE & ALIGNMENT REVIEWER of a software implementation plan.

Mode: Adversarial. Your job is to FIND FAILURES, not to approve, not to suggest
improvements. Either the plan stays inside the boundaries the user drew, or it
does not.

You have NO context from previous reviews. Judge fresh.

Read \`resources/rubrics/orchestration/plan-review-rubric-adversarial.md\`
section C (Scope & Alignment) and apply criteria C1-C5.

Apply mobile advisories M1-M4 only as \`advisories\`.`,
  }[role]

  return `${header}

Your output is the structured verdict object (the StructuredOutput tool). Set
\`reviewer\` to "${role}". Set \`verdict\` to PASS only if \`blockers\` is empty,
FAIL if any blocker is present. Every blocker MUST cite a rubric rule ID and at
least one { file, line, snippet } evidence citation.

---
ORIGINAL USER REQUEST:
${userRequest}

PLAN UNDER REVIEW:
${planText}

ITERATION: ${iteration}
---`
}

function dedupeAdvisories(advisories) {
  const seen = new Set()
  const out = []
  for (const a of advisories) {
    const firstCite = Array.isArray(a.evidence) && a.evidence[0] ? a.evidence[0] : {}
    const key = `${a.rule}|${firstCite.file || ''}|${firstCite.line ?? ''}`
    if (seen.has(key)) continue
    seen.add(key)
    out.push(a)
  }
  return out
}

// --- script body -----------------------------------------------------------

const planText = (args && args.planText) || ''
const userRequest = (args && args.userRequest) || ''
const iteration = (args && Number.isInteger(args.iteration) && args.iteration >= 1) ? args.iteration : 1

if (!planText || planText.replace(/\s/g, '').length < 50) {
  return {
    error: 'empty_or_stub_plan',
    overall_verdict: 'FAIL',
    iteration,
    blocking_reviewers: [],
    all_blockers: [{ rule: 'X0-empty-plan', summary: 'Plan appears empty or stub (<50 non-whitespace chars).', evidence: [] }],
    all_advisories: [],
    max_iterations_reached: iteration >= 3,
  }
}

phase('Review')

// Hard barrier: all three fresh, isolated reviewers always run and always
// return. A thunk that throws resolves to null (schema-invalid after retries or
// a died reviewer) — mapped to a synthetic malformed-response FAIL, mirroring
// SKILL.md Step 2's X1-malformed-response handling.
const raw = await parallel(
  ROLES.map((role) => () =>
    agent(reviewerPrompt(role, planText, userRequest, iteration), {
      schema: VERDICT_SCHEMA,
      label: `plan-review:${role}`,
      phase: 'Review',
    }).then((v) => ({ role, v }))
  )
)

phase('Aggregate')

const verdicts = ROLES.map((role) => {
  const hit = raw.find((r) => r && r.role === role)
  if (hit && hit.v) return hit.v
  // Reviewer died or never produced schema-valid output → synthetic FAIL.
  return {
    reviewer: role,
    iteration,
    verdict: 'FAIL',
    blockers: [{ rule: 'X1-malformed-response', summary: 'Reviewer returned unparseable response twice.', evidence: [] }],
    advisories: [],
    reviewed_files: [],
  }
})

const overall_verdict = verdicts.every((v) => v.verdict === 'PASS') ? 'PASS' : 'FAIL'
const blocking_reviewers = verdicts.filter((v) => v.verdict === 'FAIL').map((v) => v.reviewer)
const all_blockers = verdicts.filter((v) => v.verdict === 'FAIL').flatMap((v) => v.blockers || [])
const all_advisories = dedupeAdvisories(verdicts.flatMap((v) => v.advisories || []))

log(`Plan review iteration ${iteration}: ${overall_verdict} (${blocking_reviewers.length} blocking reviewer(s), ${all_blockers.length} blocker(s))`)

// max_iterations_reached mirrors the prose gate: escalation happens at the 3rd
// FAIL. The workflow runs ONE pass and returns; the orchestrator/command owns
// the revise-loop, iteration increment, and human escalation (SKILL Step 4b/4c).
return {
  overall_verdict,
  iteration,
  blocking_reviewers,
  all_blockers,
  all_advisories,
  max_iterations_reached: iteration >= 3,
}
