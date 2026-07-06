---
name: "iterative-build-loop"
description: "A baton-based system for building mobile features across multiple Claude Code sessions with persistent progress tracking and simulator verification between steps."
source_type: "skill"
source_file: "skills/iterative-build-loop.md"
---

# iterative-build-loop

Migrated from `skills/iterative-build-loop.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Iterative Build Loop

A baton-based system for building mobile features across multiple Claude Code sessions with persistent progress tracking and simulator verification between steps.

## Problem

Complex mobile features -- multi-screen flows, features requiring native integration, or features needing design review between steps -- cannot be completed in a single Claude Code session. Without a structured handoff system, context is lost between sessions. Developers restart from scratch, forget what was already verified, or skip verification steps. The result is features that are partially built, untested, and poorly documented.

## Solution

### 1. Baton File Structure

Create a `.claude/next-step.md` file at each iteration boundary:

```markdown
# Next Step Baton

## Feature: [Feature Name]
## Progress: [X]% complete
## Session: [N] of ~[estimated total]
## Last Updated: [ISO timestamp]

## Completed Steps
- [x] Step 1: [description] (verified on simulator)
- [x] Step 2: [description] (verified on simulator)

## Current State
- Files modified: [list of files touched in last session]
- Build status: [passing/failing]
- Known issues: [any issues discovered during verification]

## Next Step
### What to build
[Precise description of the next piece of work]

### Files to modify
- `src/screens/FeatureScreen.tsx` - Add [specific functionality]
- `src/hooks/useFeatureData.ts` - Implement [specific hook]

### Acceptance criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

### Verification command
```bash
# Run on simulator
npx expo start  # or flutter run
# Navigate to: Tab > Screen > Action
# Expected: [describe expected behavior]
```

## Context for Next Session
[Key decisions, architectural notes, or constraints the next session needs]
```markdown

### 2. Build Loop Lifecycle

```
Session 1: Plan + Build Step 1
  |
  +-- Read feature spec (from prompt-to-screen output)
  +-- Break into 3-7 buildable steps
  +-- Build step 1
  +-- Verify on simulator
  +-- Write next-step.md baton
  |
Session 2: Build Step 2
  |
  +-- Read next-step.md
  +-- Build step 2
  +-- Verify on simulator
  +-- Update next-step.md baton
  |
  ... repeat ...
  |
Session N: Build Final Step + Cleanup
  |
  +-- Read next-step.md
  +-- Build final step
  +-- Full feature verification
  +-- Delete next-step.md
  +-- Write feature summary
```markdown

### 3. Step Planning Template

Break features into steps that are each independently verifiable:

```typescript
interface BuildStep {
  /** Step number */
  step: number;
  /** Human-readable description */
  description: string;
  /** Files this step will create or modify */
  files: string[];
  /** How to verify this step on simulator */
  verification: string;
  /** Estimated completion percentage after this step */
  progressAfter: number;
  /** Dependencies on previous steps */
  dependsOn: number[];
}

// Example: "Add user profile screen with edit functionality"
const profileFeatureSteps: BuildStep[] = [
  {
    step: 1,
    description: 'Create ProfileScreen with static layout and navigation entry',
    files: ['src/screens/ProfileScreen.tsx', 'src/navigation/AppNavigator.tsx'],
    verification: 'Navigate to Profile tab, see placeholder content',
    progressAfter: 20,
    dependsOn: [],
  },
  {
    step: 2,
    description: 'Add useProfile hook with API integration',
    files: ['src/hooks/useProfile.ts', 'src/api/profile.ts'],
    verification: 'Profile screen shows real user data from API',
    progressAfter: 40,
    dependsOn: [1],
  },
  {
    step: 3,
    description: 'Build EditProfileSheet modal with form fields',
    files: ['src/screens/EditProfileSheet.tsx', 'src/hooks/useEditProfile.ts'],
    verification: 'Tap edit button, sheet slides up with populated fields',
    progressAfter: 60,
    dependsOn: [1, 2],
  },
  {
    step: 4,
    description: 'Add form validation and save mutation',
    files: ['src/hooks/useEditProfile.ts', 'src/api/profile.ts'],
    verification: 'Submit invalid data -> see errors; submit valid data -> success',
    progressAfter: 80,
    dependsOn: [3],
  },
  {
    step: 5,
    description: 'Add avatar upload with image picker',
    files: ['src/components/AvatarPicker.tsx', 'src/hooks/useImageUpload.ts'],
    verification: 'Tap avatar -> picker opens -> selected image uploads and displays',
    progressAfter: 100,
    dependsOn: [2, 3],
  },
];
```

### 4. Simulator Verification Commands

```bash
# React Native (Expo)
npx expo start --ios          # Launch iOS simulator
npx expo start --android      # Launch Android emulator

# React Native (bare)
npx react-native run-ios --simulator="iPhone 15 Pro"
npx react-native run-android

# Flutter
flutter run -d "iPhone 15 Pro"
flutter run -d emulator-5554

# Take verification screenshot
xcrun simctl io booted screenshot ~/Desktop/step-1-verify.png     # iOS
adb exec-out screencap -p > ~/Desktop/step-1-verify.png           # Android
```

### 5. Progress Tracking Integration

```typescript
// .claude/build-progress.json
{
  "feature": "user-profile",
  "totalSteps": 5,
  "currentStep": 3,
  "percentComplete": 60,
  "sessions": [
    {
      "session": 1,
      "date": "2025-03-15T10:00:00Z",
      "stepsCompleted": [1, 2],
      "duration": "~25 minutes",
      "notes": "Navigation and API integration done"
    },
    {
      "session": 2,
      "date": "2025-03-15T14:00:00Z",
      "stepsCompleted": [3],
      "duration": "~20 minutes",
      "notes": "Edit sheet built, designer wants rounded corners on avatar"
    }
  ],
  "blockers": [],
  "designFeedback": [
    "Avatar should have 8px border radius, not circular"
  ]
}
```

### 6. Session Start Protocol

At the beginning of each session, follow this protocol:

```markdown
## Session Start Checklist

1. Read `.claude/next-step.md` if it exists
2. Read `.claude/build-progress.json` if it exists
3. Run `git status` to check for uncommitted changes from last session
4. Run the build to confirm the project compiles:
   - `npx expo start` or `flutter run --no-hot`
5. Verify the last completed step still works on simulator
6. Proceed with the next step described in the baton file
```

### 7. Session End Protocol

```markdown
## Session End Checklist

1. Verify the current step works on simulator (see `verification-before-completion` skill — require fresh evidence, not assumptions). If the step has a reference design, also run the advisory Design Reference Comparison (section 8).
2. Run tests: `npm test` or `flutter test`
   - Do not claim tests pass without reading the output. See `verification-before-completion`.
3. Commit changes with descriptive message
4. Update `.claude/next-step.md` with:
   - Mark completed steps
   - Update progress percentage
   - Write precise next step description
   - Note any issues or design feedback
5. Update `.claude/build-progress.json`
6. If feature is complete:
   - Delete `.claude/next-step.md`
   - Archive `.claude/build-progress.json`
   - Write feature summary in commit message
```

### 8. Design Reference Comparison (optional, advisory)

When a step has a reference design -- an AI-generated mockup (Claude artifact, Google Stitch export, or any screenshot/spec) -- add a visual comparison to the verify step. This is **advisory only**: a generated design is a seed, not a contract, so divergences are flagged for judgment and NEVER block the loop.

1. **Capture ACTUAL** -- screenshot the running screen:
   ```bash
   bash scripts/sim-control.sh screenshot ~/Desktop/step-N-actual.png
   ```
2. **Read EXPECTED** -- point Claude vision at the reference design image. No Figma or MCP needed; Claude reads layout, structure, colors, and spacing directly from the image.
3. **Compare** -- list visible divergences in plain language: missing/extra sections, wrong layout direction, obviously-off colors or spacing, wrong component variant. Do not measure pixels; estimate.
4. **Record, don't gate** -- append findings to `build-progress.json` -> `designFeedback[]`. Address them in a later step or accept them. The loop continues either way.

Skip this entirely when there is no reference design, or when the design tool already emitted the implementation code (the screen *is* the design -- nothing independent to compare against).

## Why This Works

The baton file acts as a persistent context bridge between sessions. Each session starts by reading the baton and ends by writing the next one, creating a chain of documented progress. The build-verify-document cycle ensures that every step is confirmed working on a simulator before moving on, preventing the accumulation of untested code. Progress tracking makes it easy to estimate remaining work and communicate status to stakeholders. The `verification-before-completion` skill ensures that no step is declared done without fresh evidence — no "should work" or "probably passes" claims.

## Edge Cases

- **Session crash mid-step**: the baton from the previous session is still valid; re-read it and decide whether to resume or redo the current step based on `git diff`
- **Design feedback between sessions**: add a `designFeedback` array to `build-progress.json`; the next session should address feedback before continuing
- **Dependency changes between sessions**: if `package.json` or `pubspec.yaml` changed, run install before proceeding
- **Build failure on session start**: document the failure in the baton and fix it as the first action of the new session
- **Feature scope expansion**: re-plan remaining steps and update the total count; do not squeeze new work into existing steps
- **Parallel features**: use separate baton files named by feature (e.g., `next-step-profile.md`, `next-step-settings.md`)

## Verification

1. **Baton completeness**: every baton file contains all required sections (completed steps, current state, next step, verification command)
2. **Progress accuracy**: the percentage in the baton matches `currentStep / totalSteps`
3. **Git hygiene**: each session ends with a commit; no uncommitted changes span sessions
4. **Simulator verification**: each completed step has a verification screenshot or confirmation note
5. **No orphan batons**: when a feature is complete, the baton file is deleted

## References

- Claude Code Best Practices: https://docs.anthropic.com/en/docs/claude-code/best-practices
- Expo CLI Reference: https://docs.expo.dev/more/expo-cli/
- Flutter CLI Reference: https://docs.flutter.dev/reference/flutter-cli
