---
name: "upgrade-deps"
description: "Safely upgrade mobile app dependencies with compatibility checks and testing"
source_type: "command"
source_file: "commands/upgrade-deps.md"
---

# upgrade-deps

Migrated from `commands/upgrade-deps.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:upgrade-deps`; invoke it as `$upgrade-deps` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# Upgrade Dependencies

Safely upgrade mobile app dependencies.

## Phase 1: Analysis (0-25%)

### Current State Assessment
```bash
# React Native
npx npm-check-updates
yarn outdated

# Flutter
flutter pub outdated
```

### Dependency Inventory
```markdown
| Package | Current | Latest | Type | Breaking |
|---------|---------|--------|------|----------|
| react-native | 0.72.0 | 0.73.0 | core | Yes |
| @react-navigation/native | 6.0.0 | 6.1.0 | nav | No |
```

### Prioritization
1. **Security patches** - Immediate
2. **Bug fixes** - High priority
3. **Minor versions** - Medium
4. **Major versions** - Plan carefully

### Output
- Dependency audit report
- Upgrade priority list
- Breaking change inventory

## Phase 2: Compatibility Check (25-50%)

### Breaking Change Research
For each major upgrade:
- Read changelog/migration guide
- Check GitHub issues
- Verify peer dependency compatibility

### React Native Specific
```markdown
Check compatibility:
- React version alignment
- Native module compatibility
- Metro bundler requirements
- Hermes engine version
```

### Flutter Specific
```markdown
Check compatibility:
- Dart SDK version
- Flutter SDK version
- Plugin compatibility
- Gradle/CocoaPods versions
```

### Compatibility Matrix
```markdown
| Package | Requires | Compatible With |
|---------|----------|-----------------|
| RN 0.73 | React 18.2 | Hermes 0.12 |
| Nav 6.x | RN 0.63+ | React 16.8+ |
```

### Output
- Compatibility report
- Upgrade order determined
- Risk assessment

## Phase 3: Upgrade (50-75%)

### Pre-Upgrade Preparation
```bash
# Create upgrade branch
git checkout -b chore/dependency-upgrades

# Clean install
rm -rf node_modules
rm yarn.lock  # or package-lock.json
```

### Upgrade Process
1. **Core framework first**
   ```bash
   # React Native
   npx react-native upgrade

   # Flutter
   flutter upgrade
   ```

2. **Navigation packages**

3. **State management**

4. **Native modules**

5. **Development dependencies**

### Migration Steps
Apply breaking change migrations:
- API changes
- Import path changes
- Configuration updates

### Output
- Dependencies upgraded
- Migrations applied
- Code changes committed

## Phase 4: Validation (75-100%)

### Testing Checklist
```markdown
Build Tests:
- [ ] iOS build succeeds
- [ ] Android build succeeds
- [ ] No TypeScript/Dart errors

Runtime Tests:
- [ ] App launches on iOS
- [ ] App launches on Android
- [ ] Navigation works
- [ ] API calls work
- [ ] Auth flow works

Regression Tests:
- [ ] All unit tests pass
- [ ] All E2E tests pass
- [ ] Manual smoke test
```

### Performance Check
- Startup time comparison
- Bundle size comparison
- Memory usage check

### Rollback Plan
```bash
# If issues found
git checkout main
git branch -D chore/dependency-upgrades
```

### Output
- Validation report
- Performance comparison
- PR ready for review

## Completion Checklist

- [ ] All target dependencies upgraded
- [ ] No breaking changes unresolved
- [ ] All tests passing
- [ ] Both platforms build
- [ ] Performance acceptable
- [ ] Documentation updated
- [ ] Changelog updated
