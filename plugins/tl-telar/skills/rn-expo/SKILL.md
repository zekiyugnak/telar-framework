---
name: "rn-expo"
description: "Modern Expo development with EAS Build and Expo Router."
source_type: "skill"
source_file: "skills/rn-expo.md"
---

# rn-expo

Migrated from `skills/rn-expo.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Expo Development

Modern Expo development with EAS Build and Expo Router.

## Project Setup

```bash
# Create new Expo project
npx create-expo-app@latest my-app

# With Expo Router template
npx create-expo-app@latest my-app --template tabs
```

## Expo Router

```typescript
// app/_layout.tsx
import { Stack } from 'expo-router'

export default function Layout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: 'Home' }} />
      <Stack.Screen name="profile/[id]" options={{ title: 'Profile' }} />
    </Stack>
  )
}

// app/index.tsx
import { Link } from 'expo-router'

export default function Home() {
  return (
    <View>
      <Link href="/profile/123">Go to Profile</Link>
    </View>
  )
}

// app/profile/[id].tsx
import { useLocalSearchParams } from 'expo-router'

export default function Profile() {
  const { id } = useLocalSearchParams()
  return <Text>Profile: {id}</Text>
}
```

## EAS Build

```json
// eas.json
{
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "preview": {
      "distribution": "internal"
    },
    "production": {
      "autoIncrement": true
    }
  }
}
```

```bash
# Build for development
eas build --profile development --platform ios

# Build for production
eas build --profile production --platform all

# Submit to stores
eas submit -p ios
eas submit -p android
```

## Expo APIs

```typescript
import * as Camera from 'expo-camera'
import * as Location from 'expo-location'
import * as Notifications from 'expo-notifications'

// Camera
const { status } = await Camera.requestCameraPermissionsAsync()

// Location
const location = await Location.getCurrentPositionAsync()

// Notifications
await Notifications.scheduleNotificationAsync({
  content: { title: 'Reminder', body: 'Check your tasks' },
  trigger: { seconds: 60 },
})
```

## Best Practices

- Use development builds for native modules
- Configure EAS early in project
- Use Expo Router for file-based routing
- Check Expo SDK compatibility before adding packages
