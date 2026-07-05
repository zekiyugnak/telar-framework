# Mobile App Quality Gates

## Blocking-gate doctrine (intent-level; applies universally)

Quality gates in this plugin come in two tiers:

### Tier 1 — Mechanical gates (ALWAYS blocking)

These have machine-checkable evidence and clear pass/fail semantics:

| Gate | Source of truth | Blocking? |
|---|---|---|
| Coverage threshold | `.tl-telar-thresholds.json` `enforcement.coverage_command` | ALWAYS when `coverage_strict: true` (default false on safe-default; framework-aware setup flips it true) |
| File-scope check | `git diff` vs WU `file_scope` (content-aware baseline attribution) | ALWAYS in orchestrated mode |
| Type check / lint / test exit codes | Project's own `tsc`, `eslint`, `vitest`/`jest`/`flutter test` | ALWAYS — non-zero exit blocks Phase 4 COMMIT |

### Tier 2 — Mobile-extended gates (advisory by default, opt-in blocking)

| Gate | Source | Default | To enable blocking |
|---|---|---|---|
| Performance smoke | `scripts/perf-smoke.sh` | Advisory (exits 0 unless strict) | Set `enforcement.perf_strict: true` + wire real measurement |
| APK/IPA size | `scripts/size-check.sh` | Advisory | Set `enforcement.size_strict: true` + ensure build artifacts exist |
| Accessibility audit | `enforcement.a11y_command` | Advisory | Set `enforcement.a11y_strict: true` + configure real a11y audit tool |
| Simulator-smoke screenshot | Captured as evidence | Advisory in MVP | Sub-spec 4+ may promote to blocking |

### Why two tiers

Mobile projects vary wildly in what tooling is wired up. A fresh React Native project may have Jest configured (so coverage works) but no Maestro/Detox flow (so perf-smoke can only be a stub). A mature Flutter project may have full instrumentation including FPS measurement. The two-tier model lets the orchestrator ship working defaults everywhere without false-failing on infrastructure that simply doesn't exist yet.

### The orchestrator's contract

`/tl-telar:orchestrate` reads `.tl-telar-thresholds.json` at Phase 2 VALIDATE. For each gate:
- If `*_strict: false`: run the command, log the result, but do NOT block on non-zero exit.
- If `*_strict: true`: run the command, BLOCK Phase 4 COMMIT on non-zero exit. After 3 retries → human escalation.

This contract applies to orchestrated mode (`/tl-telar:orchestrate`). Legacy commands (`/tl-telar:add-feature`, etc.) continue to use their existing review-gates skill unchanged — they do not consult `.tl-telar-thresholds.json`.

## Pre-Commit Requirements

### Code Quality
- [ ] Linter passes (dart analyze / eslint)
- [ ] No TypeScript/Dart errors
- [ ] No console.log / print statements in production code
- [ ] No TODO comments in critical paths

### Testing
- [ ] Unit tests pass
- [ ] New code has test coverage
- [ ] No snapshot test failures (if applicable)

## Pre-PR Requirements

### Code Review Checklist
- [ ] Follows project architecture patterns
- [ ] State management correctly implemented
- [ ] Error handling in place
- [ ] Loading states handled
- [ ] Offline behavior considered

### Testing
- [ ] Unit test coverage > 70%
- [ ] Integration tests for new features
- [ ] Manual testing on iOS and Android

## Pre-Release Requirements

### Functional
- [ ] All acceptance criteria met
- [ ] Edge cases handled
- [ ] Deep links work correctly
- [ ] Push notifications tested
- [ ] Analytics events tracked

### Performance
- [ ] App startup < 3 seconds
- [ ] List scrolling at 60 FPS
- [ ] Memory stable over extended use
- [ ] No battery drain issues
- [ ] Bundle size within budget

### Compatibility
- [ ] Tested on minimum OS versions (iOS 13+, Android 7+)
- [ ] Tested on different screen sizes
- [ ] Tested on low-end devices
- [ ] RTL layout tested (if applicable)
- [ ] Dark mode tested

### Accessibility
- [ ] VoiceOver/TalkBack tested
- [ ] Font scaling tested (up to 200%)
- [ ] Color contrast meets WCAG AA
- [ ] Touch targets minimum 44x44 pt

### Security
- [ ] No sensitive data in logs
- [ ] API keys not in source code
- [ ] Certificate pinning enabled
- [ ] Secure storage for credentials

### Store Compliance
- [ ] Privacy policy updated
- [ ] App permissions minimized
- [ ] Store screenshots current
- [ ] Release notes written
- [ ] Age rating appropriate

## Post-Release Monitoring

### First 24 Hours
- [ ] Crash-free rate > 99%
- [ ] No critical bugs reported
- [ ] Analytics data flowing
- [ ] Push notifications working

### First Week
- [ ] User reviews monitored
- [ ] Performance metrics stable
- [ ] No major issues escalated
- [ ] Hotfix capability verified
