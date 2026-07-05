# Design Review Gate — ReviewResult Schema

Each of the 6 collaborative reviewers returns a single JSON object matching this schema. The aggregator (the design-review-gate skill) consumes the 6 verdicts to produce overall APPROVED / NEEDS_REVISION.

## Per-reviewer schema

```json
{
  "reviewer": "pm|architect|designer|security-design|cto|mobile-platform",
  "iteration": 1,
  "verdict": "APPROVED" | "NEEDS_REVISION",
  "blockers": [
    {
      "rule": "PM2",
      "summary": "MVP scope ambiguous — what's deferred to v2?",
      "evidence": [{"file":"RESEARCH.md","line":42,"snippet":"...consider adding..."}],
      "explanation": "Doc lists 'consider adding' for 3 features; ambiguous whether they're MVP or future."
    }
  ],
  "suggestions": [
    {
      "rule": "AR5",
      "summary": "State management choice not justified",
      "suggestion": "Brief one-paragraph compare-table: Zustand vs Redux Toolkit, why Zustand for this feature."
    }
  ],
  "questions": [
    {
      "topic": "rollback strategy",
      "question": "If the new payment SDK rejects 5%+ transactions, how do we revert?"
    }
  ],
  "use_case_analysis": {
    "who": "...",
    "wants": "...",
    "so_that": "...",
    "when": "..."
  },
  "threat_model": {
    "high_risk": [{"threat":"...","asset":"...","mitigation":"..."}],
    "medium_risk": [],
    "mitigations_required": []
  },
  "reviewed_doc": "docs/plans/login-flow-design.md"
}
```

## Field semantics

| Field | Required by | Notes |
|---|---|---|
| `reviewer` | all | One of the 6 role keys |
| `iteration` | all | Starts 1, increments per gate retry |
| `verdict` | all | APPROVED iff `blockers` is empty AND reviewer judges design adoption-ready |
| `blockers` | all | Cite rubric rule IDs (PM1-PM4, AR1-AR5, DE1-DE5, SD1-SD5, CT1-CT5, MP1-MP5) |
| `suggestions` | all | Optional improvements; do NOT block APPROVED on their absence |
| `questions` | all | Open questions the reviewer wants clarified before next iteration |
| `use_case_analysis` | PM only | Required when reviewer is PM, omit otherwise |
| `threat_model` | Security-Design only | Required when reviewer is Security-Design, omit otherwise |
| `reviewed_doc` | all | The file path the reviewer read |

## Aggregated verdict (built by the gate skill)

```json
{
  "overall_verdict": "APPROVED" | "NEEDS_REVISION",
  "iteration": 1,
  "blocking_reviewers": ["pm","security-design"],
  "all_blockers": [...],
  "all_suggestions": [...],
  "all_questions": [...],
  "use_case_analysis": {...},
  "threat_model": {...},
  "max_iterations_reached": false
}
```

`overall_verdict` is `APPROVED` only when ALL 6 reviewers returned APPROVED.
