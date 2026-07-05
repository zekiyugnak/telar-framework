---
name: "testing-pyramid-mobile"
description: "Strategic approach to mobile app testing."
source_type: "skill"
source_file: "skills/testing-pyramid-mobile.md"
---

# testing-pyramid-mobile

Migrated from `skills/testing-pyramid-mobile.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Mobile Testing Pyramid

Strategic approach to mobile app testing.

## Test Pyramid Structure

```markdown
                 /\
                /  \
               / E2E \         5-10% - Full user flows
              /------\
             /        \
            / Integration \    20-30% - Component interactions
           /--------------\
          /                \
         /    Unit Tests    \  60-70% - Logic, utilities, hooks
        /--------------------\
```

## What to Test at Each Level

```markdown
Unit Tests (60-70%):
✅ Utility functions
✅ Custom hooks
✅ State management logic
✅ Data transformations
✅ Validation logic

Integration Tests (20-30%):
✅ Component rendering
✅ User interactions
✅ Navigation flows
✅ API integration (mocked)
✅ State management integration

E2E Tests (5-10%):
✅ Critical user journeys
✅ Authentication flow
✅ Purchase/payment flows
✅ Core feature smoke tests
```

## Coverage Guidelines

```typescript
// jest.config.js
module.exports = {
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 70,
      statements: 70,
    },
    './src/utils/': {
      branches: 90,
      functions: 90,
    },
  },
}
```

## Testing Priority Matrix

```markdown
High Priority:
- Authentication/authorization
- Payment processing
- Data persistence
- Core business logic

Medium Priority:
- Navigation flows
- Form validation
- API error handling
- Offline behavior

Lower Priority:
- UI animations
- Third-party integrations
- Edge case scenarios
```

## Best Practices

- Focus unit tests on business logic
- Use integration tests for user flows
- Reserve E2E for critical paths only
- Balance coverage with maintenance cost
