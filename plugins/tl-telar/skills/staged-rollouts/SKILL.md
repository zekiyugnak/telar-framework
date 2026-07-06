---
name: "staged-rollouts"
description: "Implementing safe, gradual app releases."
source_type: "skill"
source_file: "skills/staged-rollouts.md"
---

# staged-rollouts

Migrated from `skills/staged-rollouts.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Staged Rollouts

Implementing safe, gradual app releases.

## iOS Phased Release

```markdown
App Store Connect:
1. Upload build to App Store Connect
2. Submit for review
3. After approval, choose "Phased Release"

Phases (automatic):
- Day 1: 1%
- Day 2: 2%
- Day 3: 5%
- Day 4: 10%
- Day 5: 20%
- Day 6: 50%
- Day 7: 100%

Controls:
- Pause at any phase
- Resume when ready
- Release to all immediately
```

## Android Staged Rollout

```markdown
Play Console:
1. Go to Release > Production
2. Create new release
3. Set rollout percentage

Recommended stages:
- 1% - Initial monitoring
- 5% - Early feedback
- 20% - Broader testing
- 50% - Pre-full release
- 100% - Full release

# Fastlane automation
lane :staged_release do |options|
  upload_to_play_store(
    track: 'production',
    rollout: options[:percentage] || '0.1'
  )
end
```

## Monitoring During Rollout

```typescript
// Track version adoption
analytics.setUserProperty('app_version', version)

// Monitor key metrics
const metrics = {
  crashFreeRate: getCrashFreeRate(),
  apiErrorRate: getApiErrorRate(),
  userFeedback: getFeedbackScore(),
}

// Alert thresholds
if (metrics.crashFreeRate < 99.5) {
  alertTeam('Crash rate elevated - consider pause')
}
```

## Rollback Strategy

```markdown
iOS:
- Cannot truly rollback
- Release previous version as new update
- Use feature flags to disable features

Android:
- Halt staged rollout
- Users keep current version
- Fix and release new version

Feature Flags:
- Disable problematic features remotely
- No new release required
- Instant mitigation
```

## Best Practices

- Start with 1% and monitor
- Set up crash/error alerts
- Have rollback plan ready
- Use feature flags for quick mitigation
