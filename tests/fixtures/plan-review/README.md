# Plan-Review Test Fixtures

These fixtures exercise `skills/orchestration/plan-review-gate` against
synthetic plans. To make rubric rule A1 (path-must-exist) honestly
testable, the fixtures frame their hypothetical "goal" as adding
something to **this plugin repo** rather than a consumer mobile app.

Run a fixture through the gate:

```bash
# In a Claude Code session where the telar-framework is active:
/tl-telar:review-plan --plan-file tests/fixtures/plan-review/sample-bad-plan.md
/tl-telar:review-plan --plan-file tests/fixtures/plan-review/sample-good-plan.md
```

Expected outcomes:

| Fixture | Expected overall verdict | Expected findings |
|---|---|---|
| sample-bad-plan.md | FAIL | A1, A2, A3, A5, A6, B2, B3, B5, C2, C3 |
| sample-good-plan.md | PASS | At most advisories (no blockers) |

If you change real plugin paths (e.g., delete `scripts/sim-control.sh`), the
sample-good-plan fixture may need updates because its A1-clean paths
become A1-failing.
