---
name: "mobile-commit-convention"
description: "Mobile-specific conventional commit format that provides meaningful changelogs and supports platform-specific scoping."
source_type: "skill"
source_file: "skills/mobile-commit-convention.md"
---

# mobile-commit-convention

Migrated from `skills/mobile-commit-convention.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Mobile Commit Convention

Mobile-specific conventional commit format that provides meaningful changelogs and supports platform-specific scoping.

## Problem

Generic conventional commits (`fix: something`) lack the platform context needed in cross-platform mobile projects. When reviewing a changelog, developers can't tell if a fix affects iOS, Android, or both. Native module updates that break the JS/Dart bridge aren't flagged as breaking changes. AI-generated commits lack attribution.

## Solution

### 1. Format

```text
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### 2. Types

| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `perf` | Performance improvement |
| `refactor` | Code restructuring without behavior change |
| `style` | Formatting, missing semicolons (no code change) |
| `test` | Adding or updating tests |
| `docs` | Documentation only |
| `build` | Build system or external dependency changes |
| `ci` | CI/CD configuration changes |
| `chore` | Maintenance tasks |

### 3. Mobile Scopes

| Scope | Usage |
|-------|-------|
| `ios` | iOS-specific code, Swift/ObjC, Xcode config |
| `android` | Android-specific code, Kotlin/Java, Gradle config |
| `rn` | React Native shared JS/TS code |
| `flutter` | Flutter shared Dart code |
| `nav` | Navigation changes (routes, deep links) |
| `store` | App Store or Play Store related (metadata, assets) |
| `a11y` | Accessibility improvements |
| `perf` | Performance optimizations |
| `cicd` | CI/CD pipeline changes |
| `signing` | Code signing, certificates, provisioning |

### 4. Examples

```bash
# Platform-specific fixes
fix(ios): resolve Keychain access after backgrounding
fix(android): correct status bar color on Android 14+
fix(rn): prevent re-render loop in useAuth hook

# Features
feat(flutter): add pull-to-refresh on profile screen
feat(nav): implement deep link handling for /product/:id
feat(a11y): add VoiceOver labels to checkout flow

# Performance
perf(rn): memoize FlatList renderItem to prevent re-renders
perf(flutter): switch to cached_network_image for avatar loading

# Build & CI
build(ios): update Xcode to 16.0, minimum deployment target iOS 16
build(android): bump compileSdk to 35
ci(cicd): add EAS Build step to GitHub Actions

# Store submissions
chore(store): update App Store screenshots for v2.1
chore(signing): rotate iOS distribution certificate
```

### 5. Breaking Changes

Mark breaking changes with `!` after the scope and include `BREAKING CHANGE:` in the footer:

```bash
feat(rn)!: upgrade React Navigation to v7

BREAKING CHANGE: Navigation container API changed.
- Replace `NavigationContainer` with `Navigation`
- Update all screen options to use new format
- See migration guide: https://reactnavigation.org/docs/7.x/upgrading

# Native module breaking changes MUST be flagged:
feat(ios)!: rewrite camera module with Swift concurrency

BREAKING CHANGE: CameraModule native interface changed.
- `startCapture()` is now async
- Requires Xcode 16+ and iOS 16+
- Run `pod install` after upgrade
```

### 6. AI Co-Authorship

All AI-assisted commits should include co-authorship attribution:

```bash
feat(flutter): implement biometric auth screen

Adds fingerprint and Face ID authentication using local_auth package.
Includes fallback to PIN entry when biometrics unavailable.

Co-Authored-By: Claude <noreply@anthropic.com>
```

### 7. Multi-Platform Commits

When a change affects both platforms, use the framework scope:

```bash
# Affects both iOS and Android through shared code
fix(rn): correct date formatting in transaction list

# If truly platform-independent
fix: update error message strings for clarity
```

## Verification

1. Every commit message matches `<type>(<scope>): <description>` format
2. Scope is from the approved list (or omitted for cross-cutting changes)
3. Native module changes that alter the bridge API include `BREAKING CHANGE`
4. AI-assisted commits include `Co-Authored-By` footer
5. Description is imperative mood, lowercase, no period at end
