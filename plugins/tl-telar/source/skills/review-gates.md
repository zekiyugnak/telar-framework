---
id: review-gates
category: skill
impact: HIGH
impactDescription: Two-stage review gates ensuring both requirement compliance and code quality before merge
tags: [review, quality, gates, spec-compliance, code-quality, verification, requirements]
capabilities:
  - Stage 1 requirement compliance checking against REQUIREMENTS.md F-x / UI-x
  - Stage 1 PLAN.md acceptance criteria verification
  - Stage 2 code quality verification
  - Mobile-specific quality checks
  - Priority-ranked findings
useWhen:
  - Reviewing code before merge
  - Verifying feature implementation matches requirements
  - Running quality checks after implementation
  - Integrated into review-code command
---

# Review Gates

Two-stage review gates ensuring both requirement compliance and code quality before merging.

## Stage 1: Requirement Compliance

**Does the implementation meet the requirements?**

### 1A: REQUIREMENTS.md Compliance

For each F-x and UI-x covered by this implementation:

```markdown
## Requirements Compliance

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| F-1 | Email auth | PASS | `lib/features/auth/auth_repository.dart` |
| F-7 | Calendar view | FAIL | Missing conflict resolution (F-7 business rule 3) |
| UI-5 | Calendar screen | PASS | `lib/screens/calendar/calendar_screen.dart` |

### Verdict: FAIL (1 unmet requirement)
Action: Implement F-7 business rule 3 before Stage 2
```

### 1B: PLAN.md Acceptance Criteria

If `PLAN.md` and `PROGRESS.md` exist:

```markdown
## Task Acceptance Check

| Task | Requirement | Acceptance Criteria | Status |
|------|-------------|--------------------|---------|
| T1 | F-1 | Auth repository initialises without errors | PASS |
| T3 | F-7 | Calendar loads events for current month | PASS |
| T4 | F-7 | Conflict shown when two events overlap | FAIL |

### Verdict: FAIL (1 unmet criterion)
```

> **Both 1A and 1B must pass** before Stage 2 begins.

> **Verification requirement**: Evidence must be fresh — re-run tests and re-verify on simulator before claiming pass. See `verification-before-completion` skill.

---

## Stage 2: Code Quality

**Does the code follow project standards?**

```markdown
## Code Quality Check

### Architecture
- [ ] Follows existing project structure
- [ ] No circular dependencies
- [ ] Appropriate separation of concerns

### Patterns
- [ ] Matches existing state management approach
- [ ] Consistent error handling pattern
- [ ] Proper loading state management
- [ ] API responses validated

### Performance
- [ ] No unnecessary re-renders / rebuilds
- [ ] List rendering optimised
- [ ] No large imports
- [ ] Images optimised

### Platform Conventions
- [ ] Touch targets >= 44pt iOS / 48dp Android
- [ ] Safe area handling correct
- [ ] Platform-specific navigation patterns respected
- [ ] Deep link handling for new routes

### Accessibility
- [ ] Interactive elements have accessibility labels
- [ ] Error messages announced
- [ ] Focus order logical
- [ ] Color contrast WCAG AA

### Testing
- [ ] Unit tests for business logic
- [ ] Component tests for UI
- [ ] Edge cases covered

### Verdict: PASS / FAIL
```

---

## Integration

1. **Stage 1A (REQUIREMENTS.md)** must pass before Stage 1B
2. **Stage 1B (PLAN.md)** must pass before Stage 2
3. Stage 2 failures get priority-ranked (P1/P2/P3) findings
4. Only P1 findings block merge; P2/P3 are tracked
5. All stages require fresh verification evidence

## Verification

1. Stage 1A checks every relevant F-x and UI-x from REQUIREMENTS.md
2. Stage 1B checks every task in PLAN.md against implementation
3. Stage 2 covers all items in the code quality checklist
4. Findings are priority-ranked (P1/P2/P3)
5. Only P1 findings block merge

## References

- Used by: `commands/review-code.md`
- Complements: `rules/quality-gates.md`
- Consumes: `REQUIREMENTS.md`, `PLAN.md`, `PROGRESS.md`
- Traceability: `skills/requirements-traceability.md`
