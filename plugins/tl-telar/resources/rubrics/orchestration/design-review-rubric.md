# Design Review Rubric (Collaborative, 6-Reviewer)

## Purpose

Used by the 6 specialist reviewers in `skills/orchestration/design-review-gate/` to evaluate a design doc (typically `RESEARCH.md` or `docs/plans/*-design.md`) for adoption-readiness. Unlike the adversarial plan-review-gate (sub-spec 1, PASS/FAIL), this rubric is **collaborative**: verdict is APPROVED or NEEDS_REVISION; suggestions are allowed and welcomed.

## Reviewer mode

**Collaborative.** APPROVED if the reviewer's section criteria are met. NEEDS_REVISION otherwise. Suggestions, questions, and observations are first-class outputs (alongside required `blockers`).

Reviewers are **fresh `Task()` instances** with no prior context. They see only the design doc, the original user request, and this rubric. They never see other reviewers' findings.

## Evaluation criteria

### PM — Product Manager

A design FAILS PM review (NEEDS_REVISION) if any of:

- PM1. The user problem is unclear ("Solution looking for a problem" detection — does the doc say WHO/WANTS/SO THAT/WHEN?).
- PM2. The "MVP" scope is ambiguous (no clear cut between v1 and future iterations).
- PM3. Success metric is missing or unmeasurable ("users love it" — what does that look like quantitatively?).
- PM4. No acceptance criteria from the user's perspective.

`ReviewResult.use_case_analysis` (PM-specific): summarize the WHO/WANTS/SO THAT/WHEN in a structured block.

### Architect — Architecture & API Design

A design FAILS Architect review if any of:

- AR1. New service introduced without an interface contract spec.
- AR2. Cross-cutting concern (auth, logging, error handling) repeated inline instead of extracted.
- AR3. Database schema change without migration strategy.
- AR4. Data model inconsistent across described screens/flows (e.g., User entity shape differs by screen).
- AR5. Pattern selection unclear (when 2+ patterns are equally valid, the doc should say why this one).

### Designer — UX & DX

A design FAILS Designer review if any of:

- DE1. Inconsistent UI patterns with existing app (new modal style when modals already exist; new tab pattern when tabs already exist).
- DE2. God interface — one screen does 5+ unrelated things.
- DE3. Stringly-typed API surface (passing magic strings as state instead of typed enums/discriminated unions).
- DE4. Leaky abstraction — implementation details bleed into the user-facing API.
- DE5. Inconsistent error handling — some flows throw, some return null, some return Result<T,E>.

### Security Design — Pre-Implementation Threat Model

A design FAILS Security-Design review if any of:

- SD1. New auth flow without explicit token storage strategy (keychain/Keystore vs plain AsyncStorage).
- SD2. New endpoint exposing user data without rate-limiting consideration.
- SD3. New deeplink/Universal-link without input validation strategy.
- SD4. Sensitive operation (payment, account deletion, password change) without secondary auth (biometric, PIN, email confirm).
- SD5. PII flow described without retention/deletion policy.

`ReviewResult.threat_model` (Security-Design-specific): structured STRIDE-aligned object:
```json
{
  "high_risk": [{"threat": "...", "asset": "...", "mitigation": "..."}],
  "medium_risk": [...],
  "mitigations_required": ["..."]
}
```

### CTO — Strategic Fit & Tech Debt

A design FAILS CTO review if any of:

- CT1. Plan introduces a new framework/library duplicating existing capability.
- CT2. Tech debt taken on without explicit rationale and payoff timeline.
- CT3. Plan locks in a vendor decision that should be deferred (build vs buy not analyzed).
- CT4. Operational concern unaddressed (logging, monitoring, alerting for the new feature).
- CT5. Skill gap on the team not acknowledged (introducing Kotlin Multiplatform when team has zero Kotlin).

### Mobile-Platform — HIG + Material 3 + Platform-Adaptive

A design FAILS Mobile-Platform review if any of:

- MP1. iOS-specific platform convention violated (back button placement, swipe-to-go-back, sheet vs full-screen modal).
- MP2. Android-specific platform convention violated (Material 3 surface elevation, Up vs Back, FAB placement).
- MP3. Cross-platform feature described without per-platform adaptation note (e.g., date picker — iOS uses spinner, Android uses Material picker; design should mention).
- MP4. OS-version constraint not surfaced (feature uses API only in iOS 17+ / Android 14+; design should declare minimum and graceful degradation).
- MP5. Tablet/foldable adaptation absent on a screen that materially benefits.

## Verdict format

Each reviewer returns a single JSON object matching `references/review-result-schema.md` with `reviewer: "<pm|architect|designer|security-design|cto|mobile-platform>"` and `verdict: "APPROVED"|"NEEDS_REVISION"`.

## Iteration

The gate aggregates: ALL APPROVED → proceed. Any NEEDS_REVISION → consolidate findings, user revises design doc, re-run all 6 FRESH. Max 3 iterations → escalation (Override / Defer / Cancel — there is no "Revise" option at escalation because revisions already happened 3 times).
