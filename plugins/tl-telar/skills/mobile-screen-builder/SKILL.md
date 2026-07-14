---
name: "mobile-screen-builder"
description: "Orchestrates the iterative construction of mobile screens and multi-screen flows, from specification through scaffolding, navigation wiring, and simulator verification."
source_type: "agent"
source_file: "agents/mobile-screen-builder.md"
---

# mobile-screen-builder

Migrated from `agents/mobile-screen-builder.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Mobile Screen Builder

Orchestrates the iterative construction of mobile screens and multi-screen flows, from specification through scaffolding, navigation wiring, and simulator verification.

## Clean code & reuse

Follow the `clean-code` skill: reuse existing shared units before writing new ones; unify duplication only when sites change together for the same reason (do not force-merge coincidental similarity); keep to simplicity-first (no speculative abstraction). The Maintainability reviewer enforces this.

## Decision Framework

### Build Strategy Selection

```text
Screen Build Entry
  |
  +-- Check REQUIREMENTS.md Design Assets table for this screen
  |     |
  |     +-- Figma ref present, status = "Final"
  |     |     -> Use prompt-to-screen Mod B (auto, no need to ask)
  |     |
  |     +-- Figma ref present, status = Draft/WIP
  |     |     -> Ask user: use draft? build from spec? skip?
  |     |
  |     +-- No Figma ref ("—" or "No design")
  |     |     -> Ask user: create design first? build from spec?
  |     |
  |     +-- Screen not in Design Assets table
  |           -> Ask user: add to REQUIREMENTS.md first? describe now?
  |
  +-- Is there a screen specification?
  |     |
  |     +-- YES -> Validate spec completeness (components, state, navigation)
  |     |          -> Proceed to complexity assessment
  |     |
  |     +-- NO  -> Use prompt-to-screen skill to generate spec
  |                -> Review with user before proceeding
  |
  +-- Complexity assessment
  |     |
  |     +-- Simple (1-3 components, no API calls, static content)
  |     |     -> Single-session build, no baton needed
  |     |
  |     +-- Medium (4-8 components, 1-2 API calls, form input)
  |     |     -> Single-session build, optional baton
  |     |
  |     +-- Complex (8+ components, multiple API calls, real-time, animations)
  |           -> Multi-session build with iterative-build-loop baton
  |
  +-- Does DESIGN.md exist?
  |     |
  |     +-- YES -> All components must import from design tokens
  |     +-- NO  -> Warn user; recommend generating DESIGN.md first
  |
  +-- Multi-screen flow?
        |
        +-- YES -> Plan build order: shared components first,
        |          then screens in navigation order
        +-- NO  -> Build the single screen directly
```

### Component Reuse Decision

```text
For each component in the screen spec:
  |
  +-- Does a matching component already exist in the project?
  |     YES -> Reuse it; do not duplicate
  |     NO  -> Continue
  |
  +-- Will this component be used on other screens?
  |     YES -> Build as shared component in src/components/
  |     NO  -> Build as screen-local component in src/screens/[Screen]/components/
  |
  +-- Does the component exist in the chosen UI library?
        YES -> Use library component with theme customization
        NO  -> Scaffold from scratch using component-scaffolding skill
```

## Core Patterns

### Pattern 1: Single Screen Build Workflow

```text
Step 1: Validate Prerequisites
  +-- Check REQUIREMENTS.md Design Assets → select prompt-to-screen mode
  +-- Read/generate screen spec
  +-- Verify DESIGN.md exists and read token definitions
  +-- Identify target navigation location
  +-- List all components needed

Step 2: Scaffold Components
  +-- For each component: reuse / wrap library / scaffold

Step 3: Build Screen
  +-- Create screen file with layout from spec
  +-- Wire components, state, loading/error/empty states
  +-- Add accessibility labels

Step 4: Wire Navigation
  +-- Add to navigator/router
  +-- Configure deep link
  +-- Wire back/close behavior

Step 5: Verify
  +-- Run on simulator: visual check
  +-- Run tests: pass
  +-- Token audit: no hardcoded colors/fonts/spacing
  +-- Accessibility: screen reader walkthrough
```

### Pattern 2: Screen File Template (Flutter)

```dart
// lib/screens/profile/profile_screen.dart
class ProfileScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const SkeletonLoader(),
        error: (e, _) => ErrorState(onRetry: () => ref.refresh(profileProvider)),
        data: (profile) => ProfileContent(profile: profile),
      ),
    );
  }
}
```

### Pattern 3: Token Validation Post-Build

```bash
# Check for hardcoded colors
grep -rn '#[0-9A-Fa-f]\{3,8\}' lib/screens/profile/ --include='*.dart'
# Expected: 0 matches

# Check for hardcoded font sizes
grep -rn 'fontSize:\s*[0-9]' lib/screens/profile/ --include='*.dart'
# Expected: 0 matches
```

## Anti-Patterns

- **Skipping Design Assets check**: building without consulting REQUIREMENTS.md first; risks ignoring an available Figma design
- **Building without a spec**: jumping into code without a validated screen spec
- **Monolithic screen files**: putting all component code in a single file
- **Skipping loading/error/empty states**: building only the happy path
- **Hardcoded navigation routes**: use typed route constants
- **Ignoring token audit**: hardcoded values diverge from DESIGN.md
- **No verification between iterations**: compounds errors

## Escalation Paths

- **Spec ambiguous**: escalate to `prompt-to-screen` to refine
- **Design tokens missing**: escalate to `mobile-design-system-architect`
- **Navigation restructuring needed**: escalate to `mobile-navigation-architect`
- **Performance issues**: escalate to `mobile-performance-optimizer`
- **Accessibility violations**: escalate to `mobile-accessibility-expert`
- **Figma MCP unavailable**: fall back to Mod A (build from requirements text)

## Referenced Skills

- `prompt-to-screen` — Screen spec generation (Mod A/B/C)
- `component-scaffolding` — Component file sets with tests
- `iterative-build-loop` — Baton-based multi-session build
- `mobile-design-system` — Design token definitions
- `requirements-gather` — REQUIREMENTS.md source
