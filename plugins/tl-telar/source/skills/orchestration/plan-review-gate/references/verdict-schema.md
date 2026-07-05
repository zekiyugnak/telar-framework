# Plan Review Gate — Verdict Schema

Each of the 3 reviewers returns a single JSON object matching this schema, and nothing else (no prose outside the JSON).

```json
{
  "reviewer": "feasibility" | "completeness" | "scope-alignment",
  "iteration": 1,
  "verdict": "PASS" | "FAIL",
  "blockers": [
    {
      "rule": "A3",
      "summary": "External SDK `react-native-foo` not installable on iOS.",
      "evidence": [
        { "file": "PLAN.md", "line": 84, "snippet": "Task 5: install react-native-foo" }
      ],
      "explanation": "react-native-foo's podspec excludes iOS; project is iOS+Android."
    }
  ],
  "advisories": [
    {
      "rule": "M1",
      "summary": "Plan touches login screen but no accessibility consideration.",
      "evidence": [
        { "file": "PLAN.md", "line": 42, "snippet": "Task 2: build LoginScreen with email + password" }
      ]
    }
  ],
  "reviewed_files": ["PLAN.md"]
}
```

## Field definitions

| Field | Type | Required | Description |
|---|---|---|---|
| `reviewer` | enum | yes | Which of the 3 roles this verdict comes from. Must match the role assigned at spawn. |
| `iteration` | integer ≥ 1 | yes | 1 on first review, increments per re-review pass. |
| `verdict` | enum | yes | `PASS` only if `blockers` array is empty. `FAIL` if any blocker present. |
| `blockers` | array of finding objects | yes | Each blocker MUST cite a `rule` ID from the rubric (e.g., `A1`, `B3`, `C2`). Empty array on PASS. |
| `advisories` | array of finding objects | yes | M1–M4 mobile advisories. Can be non-empty on either PASS or FAIL. |
| `reviewed_files` | array of strings | yes | The plan file(s) read. Usually just `PLAN.md`. |

## Finding object fields

| Field | Type | Required | Description |
|---|---|---|---|
| `rule` | string | yes | Rubric rule ID. |
| `summary` | string | yes | One-sentence finding. |
| `evidence` | array of citation objects | yes | At least one `{ file, line, snippet }` citation. Citations must be verifiable by the user. |
| `explanation` | string | conditional | Required for `blockers`, optional for `advisories`. ≤300 chars. |

## Aggregation (done by the gate orchestrator, not the reviewers)

The gate orchestrator collects all 3 verdicts and produces a single overall verdict:

```json
{
  "overall_verdict": "PASS" | "FAIL",
  "iteration": 1,
  "blocking_reviewers": ["feasibility"],
  "all_blockers": [ /* concatenated from FAILed reviewers */ ],
  "all_advisories": [ /* concatenated from all 3 reviewers */ ],
  "max_iterations_reached": false
}
```

`overall_verdict` is `PASS` only when ALL 3 reviewer verdicts are `PASS`. Otherwise `FAIL`. `blocking_reviewers` lists which reviewer(s) returned FAIL. `max_iterations_reached` is `true` only when iteration > 3.
