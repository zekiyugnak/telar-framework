---
name: "migrate-app"
description: "Migrate a native iOS/Android app to cross-platform React Native or Flutter"
source_type: "command"
source_file: "commands/migrate-app.md"
---

# migrate-app

Migrated from `commands/migrate-app.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:migrate-app`; invoke it as `$migrate-app` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# Migrate App

Migrate a native mobile app to cross-platform framework.

## Phase 1: Assessment (0-20%)

### Codebase Analysis
- Analyze source platform (iOS/Android)
- Document existing architecture
- Map all screens and features
- Identify native dependencies

### Feature Inventory
```markdown
| Feature | Complexity | Native Dependencies | Priority |
|---------|------------|---------------------|----------|
| Auth    | Medium     | Keychain, BiometricAuth | High |
| Maps    | High       | MapKit/Google Maps  | Medium |
| Camera  | Medium     | AVFoundation/Camera2| High |
```

### Dependency Audit
- List all third-party SDKs
- Check cross-platform alternatives
- Identify native-only features

### Output
- Complete feature inventory
- Dependency mapping
- Risk assessment

## Phase 2: Strategy (20-35%)

### Load Agents
```yaml
agents:
  - react-native-expert OR flutter-expert
  - mobile-navigation-architect
  - mobile-state-management
```

### Migration Approach
Choose strategy:
1. **Big Bang** - Complete rewrite
2. **Incremental** - Module by module
3. **Hybrid** - Native shell + cross-platform features

### Architecture Mapping
- Map native patterns to cross-platform equivalents
- Design new navigation structure
- Plan state management approach

### Timeline & Priorities
- Feature prioritization
- Migration phases
- Parallel development plan

### Output
- Migration strategy document
- Architecture mapping
- Phase breakdown

## Phase 3: Foundation (35-50%)

### Project Setup
```bash
# Initialize new project
npx create-expo-app@latest MigratedApp

# Or Flutter
flutter create migrated_app
```

### Core Infrastructure
1. **Navigation structure**
   - Match existing app structure
   - Deep linking configuration

2. **State management**
   - Configure state solution
   - Plan data migration

3. **API client**
   - Replicate API integration
   - Handle authentication

4. **Native bridges** (if needed)
   - iOS native module setup
   - Android native module setup

### Output
- Cross-platform project initialized
- Core infrastructure ready
- Native bridge foundation

## Phase 4: Feature Migration (50-85%)

### Load Bridge Agents
```yaml
agents:
  - ios-native-bridge (if keeping iOS native code)
  - android-native-bridge (if keeping Android native code)
```

### Migration Order
1. **Shared logic first**
   - Business logic
   - Data models
   - API services

2. **UI components**
   - Design system components
   - Common screens

3. **Platform-specific features**
   - Native module wrappers
   - Platform-specific UI

### Per-Feature Process
```markdown
For each feature:
1. Identify cross-platform equivalent
2. Implement in new framework
3. Compare behavior with original
4. Verify edge cases
5. Mark as migrated
```

### Native Module Migration
When no cross-platform equivalent:
- Create native module wrapper
- Expose to JavaScript/Dart
- Test on both platforms

### Output
- Migrated features
- Native modules created
- Feature parity tracking

## Phase 5: Validation (85-100%)

### Load Testing Agents
```yaml
agents:
  - mobile-e2e-testing-expert
  - mobile-performance-testing
```

### Validation Tasks
1. **Feature parity testing**
   - Compare with original app
   - Verify all features work

2. **Performance comparison**
   - Startup time
   - Navigation speed
   - Memory usage

3. **Platform testing**
   - iOS device testing
   - Android device testing

4. **Regression testing**
   - All user flows
   - Edge cases

### Launch Preparation
- App Store assets
- Play Store assets
- Migration announcement

### Output
- Validation report
- Performance comparison
- Launch checklist

## Completion Checklist

- [ ] All features migrated
- [ ] Feature parity verified
- [ ] Performance acceptable
- [ ] Both platforms tested
- [ ] CI/CD configured
- [ ] Store submission ready
