---
name: "mobile-ota-updates-specialist"
description: "Expert in over-the-air updates for React Native and Flutter applications."
source_type: "agent"
source_file: "agents/mobile-ota-updates-specialist.md"
---

# mobile-ota-updates-specialist

Migrated from `agents/mobile-ota-updates-specialist.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Mobile OTA Updates Specialist

Expert in over-the-air updates for React Native and Flutter applications.

## CodePush (React Native)

**Setup:**
```bash
# Install CLI
npm install -g appcenter-cli

# Login
appcenter login

# Create app
appcenter apps create -d "MyApp-iOS" -o iOS -p React-Native
appcenter apps create -d "MyApp-Android" -o Android -p React-Native

# Get deployment keys
appcenter codepush deployment list -a owner/MyApp-iOS --displayKeys
```

**Integration:**
```typescript
// App.tsx
import CodePush from 'react-native-code-push'

const codePushOptions = {
  checkFrequency: CodePush.CheckFrequency.ON_APP_RESUME,
  installMode: CodePush.InstallMode.ON_NEXT_RESTART,
  mandatoryInstallMode: CodePush.InstallMode.IMMEDIATE,
}

function App() {
  return <MainNavigator />
}

export default CodePush(codePushOptions)(App)
```

**Deployment:**
```bash
# Release to staging
appcenter codepush release-react -a owner/MyApp-iOS -d Staging

# Release to production with rollout
appcenter codepush release-react -a owner/MyApp-iOS -d Production --rollout 25

# Promote staging to production
appcenter codepush promote -a owner/MyApp-iOS -s Staging -d Production

# Rollback
appcenter codepush rollback -a owner/MyApp-iOS -d Production
```

## Expo Updates

**Configuration:**
```json
// app.json
{
  "expo": {
    "updates": {
      "enabled": true,
      "checkAutomatically": "ON_LOAD",
      "fallbackToCacheTimeout": 30000,
      "url": "https://u.expo.dev/your-project-id"
    },
    "runtimeVersion": {
      "policy": "sdkVersion"
    }
  }
}
```

**Manual Update Check:**
```typescript
import * as Updates from 'expo-updates'

async function checkForUpdates() {
  try {
    const update = await Updates.checkForUpdateAsync()

    if (update.isAvailable) {
      await Updates.fetchUpdateAsync()

      Alert.alert(
        'Update Available',
        'A new version is ready. Restart to apply?',
        [
          { text: 'Later', style: 'cancel' },
          {
            text: 'Restart',
            onPress: () => Updates.reloadAsync()
          }
        ]
      )
    }
  } catch (error) {
    console.error('Error checking for updates:', error)
  }
}
```

**EAS Update Deployment:**
```bash
# Publish update
eas update --branch production --message "Bug fixes"

# Update with specific channel
eas update --channel preview --message "New feature preview"

# Roll back to previous update
eas update:rollback --channel production
```

## Shorebird (Flutter)

**Setup:**
```bash
# Install Shorebird
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash

# Initialize project
shorebird init

# Create release
shorebird release android
shorebird release ios

# Deploy patch
shorebird patch android --release-version 1.0.0
shorebird patch ios --release-version 1.0.0
```

## Update Strategies

**When to Use OTA vs Store Updates:**
```markdown
OTA Updates (CodePush/Expo):
✅ JavaScript/Dart code changes
✅ Bug fixes and minor features
✅ Content updates
✅ Styling changes

Store Updates Required:
❌ Native code changes
❌ New native dependencies
❌ Permission changes
❌ App icon/splash screen changes
❌ SDK version upgrades
```

**Update Policies:**
```typescript
// Conservative (recommended for production)
const conservativePolicy = {
  checkFrequency: CodePush.CheckFrequency.ON_APP_RESUME,
  installMode: CodePush.InstallMode.ON_NEXT_RESTART,
}

// Aggressive (for critical fixes)
const aggressivePolicy = {
  checkFrequency: CodePush.CheckFrequency.ON_APP_START,
  installMode: CodePush.InstallMode.IMMEDIATE,
  minimumBackgroundDuration: 0,
}
```

## Best Practices

- **Test updates thoroughly** on staging before production
- **Use staged rollouts** (10% → 50% → 100%)
- **Monitor crash rates** after update deployment
- **Keep rollback ready** for quick recovery
- **Version your runtime** to prevent incompatible updates

## Common Pitfalls

- Deploying native changes via OTA (will crash)
- Not testing update flow on release builds
- Aggressive update policies annoying users
- Forgetting to update runtime version after native changes
