---
name: "setup-ota"
description: "Configure over-the-air updates with CodePush, Expo Updates, or Shorebird"
source_type: "command"
source_file: "commands/setup-ota.md"
---

# setup-ota

Migrated from `commands/setup-ota.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:setup-ota`; invoke it as `$setup-ota` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# Setup OTA Updates

Configure over-the-air updates for mobile apps.

## Phase 1: Provider Selection (0-33%)

### Load Agents
```yaml
agents:
  - mobile-ota-updates-specialist
```

### Provider Comparison
```markdown
| Provider | React Native | Flutter | Expo | Native Code |
|----------|--------------|---------|------|-------------|
| Expo Updates | ✅ (Expo) | ❌ | ✅ | ❌ |
| CodePush | ✅ | ❌ | ❌ | ❌ |
| Shorebird | ❌ | ✅ | ❌ | ✅ (Dart) |
| Firebase RC | Config only | Config only | Config only | ❌ |
```

### OTA Limitations
```markdown
Can update:
✅ JavaScript/Dart code
✅ Assets (images, fonts)
✅ Configuration

Cannot update:
❌ Native code (requires store update)
❌ Native dependencies
❌ App permissions
❌ App icons/splash screens
```

### Selection Criteria
- Framework used
- Update frequency needs
- Rollback requirements
- Budget

### Output
- OTA provider selected
- Account created

## Phase 2: Configuration (33-66%)

### Expo Updates Setup
```bash
# Already included in Expo projects
# Configure in app.json
```

```json
// app.json
{
  "expo": {
    "updates": {
      "enabled": true,
      "checkAutomatically": "ON_LOAD",
      "fallbackToCacheTimeout": 0,
      "url": "https://u.expo.dev/your-project-id"
    },
    "runtimeVersion": {
      "policy": "sdkVersion"
    }
  }
}
```

```typescript
// Check for updates in app
import * as Updates from 'expo-updates'

async function checkForUpdates() {
  if (__DEV__) return

  try {
    const update = await Updates.checkForUpdateAsync()

    if (update.isAvailable) {
      await Updates.fetchUpdateAsync()

      // Optionally ask user
      Alert.alert(
        'Update Available',
        'A new version is ready. Restart to apply?',
        [
          { text: 'Later' },
          {
            text: 'Restart',
            onPress: () => Updates.reloadAsync(),
          },
        ]
      )
    }
  } catch (error) {
    console.log('Update check failed:', error)
  }
}
```

### CodePush Setup (React Native)
```bash
# Install
npm install react-native-code-push

# Link (React Native < 0.60)
react-native link react-native-code-push

# Register app
appcenter apps create -d MyApp-iOS -o iOS -p React-Native
appcenter apps create -d MyApp-Android -o Android -p React-Native
```

```typescript
// Wrap root component
import codePush from 'react-native-code-push'

const codePushOptions = {
  checkFrequency: codePush.CheckFrequency.ON_APP_START,
  installMode: codePush.InstallMode.ON_NEXT_RESTART,
}

function App() {
  return <MainApp />
}

export default codePush(codePushOptions)(App)
```

### Shorebird Setup (Flutter)
```bash
# Install Shorebird CLI
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash

# Initialize in project
shorebird init

# Create release
shorebird release android
shorebird release ios

# Push patch
shorebird patch android
shorebird patch ios
```

```dart
// Check for updates
import 'package:shorebird_code_push/shorebird_code_push.dart';

final shorebirdCodePush = ShorebirdCodePush();

Future<void> checkForUpdates() async {
  final isUpdateAvailable = await shorebirdCodePush.isNewPatchAvailableForDownload();

  if (isUpdateAvailable) {
    await shorebirdCodePush.downloadUpdateIfAvailable();
    // Restart app to apply
  }
}
```

### Output
- OTA SDK installed
- Configuration complete

## Phase 3: Rollout Strategy (66-100%)

### Update Policies
```typescript
// Silent update (background)
const options = {
  installMode: codePush.InstallMode.ON_NEXT_RESTART,
}

// Immediate update (for critical fixes)
const options = {
  installMode: codePush.InstallMode.IMMEDIATE,
  mandatoryInstallMode: codePush.InstallMode.IMMEDIATE,
}

// Update on resume
const options = {
  installMode: codePush.InstallMode.ON_NEXT_RESUME,
  minimumBackgroundDuration: 60 * 5, // 5 minutes
}
```

### Staged Rollout
```bash
# CodePush staged rollout
appcenter codepush release-react -a MyOrg/MyApp \
  -d Production \
  --rollout 25

# Increase rollout
appcenter codepush patch -a MyOrg/MyApp Production \
  --rollout 50

# Full rollout
appcenter codepush patch -a MyOrg/MyApp Production \
  --rollout 100
```

### Rollback Strategy
```bash
# CodePush rollback
appcenter codepush rollback -a MyOrg/MyApp Production

# Expo rollback (republish previous)
eas update --branch production --message "Rollback"
```

### Version Management
```markdown
Track compatibility:
- Native version: 1.2.0 (requires store update)
- JS bundle version: 1.2.0-update.3 (OTA)

Runtime version policies:
- Expo: sdkVersion, appVersion, or custom
- CodePush: targetBinaryVersion
- Shorebird: release version
```

### CI/CD Integration
```yaml
# GitHub Actions - Expo Updates
- name: Publish update
  if: github.ref == 'refs/heads/main'
  run: |
    eas update --branch production \
      --message "${{ github.event.head_commit.message }}"
  env:
    EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}

# CodePush
- name: Deploy update
  run: |
    appcenter codepush release-react \
      -a ${{ secrets.APPCENTER_APP }} \
      -d Production \
      --rollout 25
```

### Output
- Rollout strategy defined
- CI/CD integration complete

## Completion Checklist

- [ ] OTA provider selected
- [ ] SDK installed and configured
- [ ] Update policies defined
- [ ] Staged rollout configured
- [ ] Rollback strategy documented
- [ ] CI/CD integration complete
- [ ] Version management strategy
- [ ] Documentation updated
