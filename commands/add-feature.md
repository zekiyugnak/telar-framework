---
id: add-feature
name: Add Feature
description: Add a new feature to an existing mobile application with requirements check, codebase exploration, brainstorming, planning, implementation, and review
category: command
usage: /tl-telar:add-feature [feature description]
example: /tl-telar:add-feature push notifications with deep linking
phases:
  - name: Codebase Exploration
    progress: 0-10%
  - name: Requirements Check
    progress: 10-20%
  - name: Brainstorming
    progress: 20-35%
  - name: Design & Planning
    progress: 35-50%
  - name: Implementation
    progress: 50-80%
  - name: Review & Integration
    progress: 80-100%
---

# Add Feature

> Artifacts (REQUIREMENTS.md, RESEARCH.md, PLAN.md, PROGRESS.md) are written under `tl-telar-spec/changes/<id>/` — see `skills/requirements-gather.md` → "Step 0" for change-id/domain resolution. Once the feature is complete, run `node scripts/tl-telar-spec-archive.js <change-id>` to merge into `tl-telar-spec/truth/` and archive the change folder.

Add a new feature to an existing mobile application with structured exploration, requirements check, brainstorming, planning, and review.

## Phase 0: Codebase Exploration (0-10%)

### Load Rules
```yaml
rules:
  - codebase-first
```

### Explore Project
Run `scripts/project-detect.sh` to detect platform, navigation, state management.

### Codebase Scan
- Read `package.json` or `pubspec.yaml`
- Scan existing component library
- Check design tokens / theme file
- Review existing test patterns

---

## Phase 0.5: Requirements Check (10-20%)

### Load Rules
```yaml
rules:
  - requirements-first
```

### Load Skills
```yaml
skills:
  - requirements-gather  # only if REQUIREMENTS.md needs updating
```

### Check REQUIREMENTS.md

```
Does REQUIREMENTS.md exist?

├── YES — Is this feature defined in REQUIREMENTS.md?
│     ├── YES — Note the F-x / UI-x identifiers
│     │         → proceed to Phase 0.5B
│     └── NO  — This is a new feature not yet in requirements
│               → invoke requirements-gather to add it
│               → proceed to Phase 0.5B
│
└── NO  — REQUIREMENTS.md does not exist
          → invoke requirements-gather (full requirements gathering)
          → proceed to Phase 0.5B
```

### Phase 0.5B: Design Asset Check

For each UI-x identified for this feature, check Design Assets table:
- Figma Final → `prompt-to-screen` will use Mod B automatically
- Figma Draft/WIP or missing → user will be asked at spec generation time

### Output
- Confirmed F-x / UI-x identifiers for this feature
- REQUIREMENTS.md updated if feature was new

---

## Phase 1: Brainstorming (20-35%)

### Load Skill
```yaml
skills:
  - brainstorm-first
```

### Produce RESEARCH.md
- Read REQUIREMENTS.md first
- Focus on F-x requirements for this feature
- Architecture options that fit existing codebase
- State management approach (must match existing)
- Risk assessment tied to REQUIREMENTS.md Open Items

### Blueprint Detection
- Check if feature matches an existing blueprint in `skills/blueprints/`
- If yes, suggest it and adapt to existing codebase

---

## Phase 2: Design & Planning (35-50%)

### Load Skills
```yaml
skills:
  - plan-and-track
```

### Produce PLAN.md
- Every task must reference F-x or UI-x from REQUIREMENTS.md
- Tasks feed into iterative-build-loop

---

## Phase 3: Implementation (50-80%)

### Load Relevant Skills
```yaml
skills:
  - Feature-specific skills
  - Platform-specific skills (rn-* or flutter-*)
```

1. Backend changes (if needed)
2. Core logic
3. UI components
4. Navigation integration

---

## Phase 4: Review & Integration (80-100%)

### Verification Gate
```yaml
skills:
  - verification-before-completion
  - review-gates
```

### Stage 1A: REQUIREMENTS.md Compliance
- Does implementation cover all F-x for this feature?
- Are business rules from REQUIREMENTS.md implemented?

### Stage 1B: PLAN.md Acceptance Criteria
- Are all tasks in PROGRESS.md marked complete?
- Do outputs match RESEARCH.md decisions?

### Stage 2: Code Quality
- Follows existing architecture patterns
- Platform conventions respected
- Unit tests written
- Error and loading states handled

### Integration
- Update PROGRESS.md to "Complete"
- Commit using mobile-commit-convention
- Archive: run `node scripts/tl-telar-spec-archive.js <change-id>` — it moves the entire `tl-telar-spec/changes/<id>/` folder (PLAN.md, PROGRESS.md, REQUIREMENTS.md, RESEARCH.md, and any TRACEABILITY.md together) to `tl-telar-spec/changes/archive/<date>-<id>/` in one step, and merges any `REQUIREMENTS.delta.md` into `tl-telar-spec/truth/`. There is no separate `.claude/archive/` location.

---

## Completion Checklist

- [ ] REQUIREMENTS.md confirms feature is in scope
- [ ] F-x / UI-x identifiers noted in PLAN.md tasks
- [ ] RESEARCH.md produced
- [ ] PLAN.md tasks all completed
- [ ] Feature requirements met (Stage 1A)
- [ ] Acceptance criteria met (Stage 1B)
- [ ] Unit tests written
- [ ] Error handling implemented
- [ ] Review gates passed (spec + quality)
- [ ] No regression in existing features
