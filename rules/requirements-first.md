---
id: requirements-first
category: rule
alwaysApply: true
tags: [requirements, planning, process, gate]
---

# Requirements First

Before implementing any feature, REQUIREMENTS.md must exist and be consulted.

## Rule

When starting a new feature or significant change:

1. **Check for REQUIREMENTS.md** at `tl-telar-spec/changes/<active-change-id>/REQUIREMENTS.md` (resolve `<active-change-id>` via `.tl-telar/context/active-change.txt` — see `skills/requirements-gather.md` → "Step 0")
   - Exists and covers this feature → reference the relevant F-x / UI-x identifiers
   - Exists but does not cover this feature → add the feature to REQUIREMENTS.md first using `requirements-gather` skill, then proceed
   - Does not exist → create it using `requirements-gather` skill before any implementation

2. **Every new task in PLAN.md must reference at least one F-x or UI-x** from REQUIREMENTS.md
   - Format: `Requirement: F-x` in the task block
   - If no matching requirement exists, add it to REQUIREMENTS.md first

3. **Do not implement features that are marked Out of Scope** in REQUIREMENTS.md without explicit user confirmation to update the requirements

## Why

Implementing features without a requirements anchor leads to:
- Features that solve the wrong problem
- Scope creep that is invisible until it is too late
- Review gates that have no spec to check against
- Change management that cannot trace what broke what

## Exceptions

- Bug fixes that restore existing behaviour (no new requirements needed)
- Refactoring that changes no observable behaviour
- Test additions that cover existing behaviour
- Tooling and infrastructure changes with no user-facing impact

For all other changes: requirements first.
