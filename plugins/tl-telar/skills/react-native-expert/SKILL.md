---
name: "react-native-expert"
description: "Cross-platform mobile development specialist focusing on modern React Native patterns, performance optimization, and native integration."
source_type: "agent"
source_file: "agents/react-native-expert.md"
---

# react-native-expert

Migrated from `agents/react-native-expert.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# React Native Expert

Cross-platform mobile development specialist focusing on modern React Native patterns, performance optimization, and native integration.

## Core Architecture

**Project Structure:**
```text
src/
├── components/          # Reusable UI components
│   ├── common/         # Buttons, inputs, cards
│   └── screens/        # Screen-specific components
├── navigation/         # React Navigation setup
├── screens/            # Screen components
├── hooks/              # Custom hooks
├── services/           # API, storage, analytics
├── store/              # State management
├── utils/              # Helpers and utilities
└── types/              # TypeScript definitions
```

## Essential Patterns

**Functional Components with TypeScript:**
```typescript
import { FC, memo } from 'react'
import { View, Text, StyleSheet, ViewStyle } from 'react-native'

interface CardProps {
  title: string
  subtitle?: string
  style?: ViewStyle
  onPress?: () => void
}

export const Card: FC<CardProps> = memo(({
  title,
  subtitle,
  style,
  onPress
}) => (
  <Pressable
    onPress={onPress}
    style={({ pressed }) => [
      styles.container,
      style,
      pressed && styles.pressed
    ]}
  >
    <Text style={styles.title}>{title}</Text>
    {subtitle && <Text style={styles.subtitle}>{subtitle}</Text>}
  </Pressable>
))

const styles = StyleSheet.create({
  container: {
    padding: 16,
    borderRadius: 8,
    backgroundColor: '#fff',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  pressed: { opacity: 0.8 },
  title: { fontSize: 18, fontWeight: '600' },
  subtitle: { fontSize: 14, color: '#666', marginTop: 4 },
})
```

**Custom Hooks Pattern:**
```typescript
import { useState, useCallback, useEffect } from 'react'
import { AppState, AppStateStatus } from 'react-native'

export function useAppState() {
  const [appState, setAppState] = useState(AppState.currentState)

  useEffect(() => {
    const subscription = AppState.addEventListener(
      'change',
      (nextState: AppStateStatus) => setAppState(nextState)
    )
    return () => subscription.remove()
  }, [])

  return {
    appState,
    isActive: appState === 'active',
    isBackground: appState === 'background',
  }
}

// API Hook with loading/error states
export function useApi<T>(fetcher: () => Promise<T>) {
  const [data, setData] = useState<T | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const execute = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const result = await fetcher()
      setData(result)
    } catch (e) {
      setError(e as Error)
    } finally {
      setLoading(false)
    }
  }, [fetcher])

  return { data, loading, error, execute }
}
```

## Navigation Setup

**Type-Safe Navigation:**
```typescript
import { NavigationContainer } from '@react-navigation/native'
import { createNativeStackNavigator } from '@react-navigation/native-stack'
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs'

// Define param lists
export type RootStackParamList = {
  Auth: undefined
  Main: undefined
}

export type MainTabParamList = {
  Home: undefined
  Profile: { userId: string }
  Settings: undefined
}

// Create navigators
const Stack = createNativeStackNavigator<RootStackParamList>()
const Tab = createBottomTabNavigator<MainTabParamList>()

// Navigation with linking config
const linking = {
  prefixes: ['myapp://', 'https://myapp.com'],
  config: {
    screens: {
      Main: {
        screens: {
          Home: 'home',
          Profile: 'profile/:userId',
        },
      },
    },
  },
}

export function Navigation() {
  return (
    <NavigationContainer linking={linking}>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        <Stack.Screen name="Auth" component={AuthNavigator} />
        <Stack.Screen name="Main" component={MainTabs} />
      </Stack.Navigator>
    </NavigationContainer>
  )
}
```

## State Management

**Zustand Store:**
```typescript
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import AsyncStorage from '@react-native-async-storage/async-storage'

interface AuthState {
  user: User | null
  token: string | null
  setUser: (user: User, token: string) => void
  logout: () => void
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      setUser: (user, token) => set({ user, token }),
      logout: () => set({ user: null, token: null }),
    }),
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => AsyncStorage),
    }
  )
)
```

**React Query Setup:**
```typescript
import { QueryClient, QueryClientProvider, useQuery } from '@tanstack/react-query'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5 minutes
      retry: 2,
    },
  },
})

// Custom hook
export function useUser(userId: string) {
  return useQuery({
    queryKey: ['user', userId],
    queryFn: () => api.getUser(userId),
    enabled: !!userId,
  })
}
```

## Performance Optimization

**FlatList Optimization:**
```typescript
const renderItem = useCallback(({ item }: { item: Item }) => (
  <MemoizedItem item={item} onPress={handlePress} />
), [handlePress])

const keyExtractor = useCallback((item: Item) => item.id, [])

const getItemLayout = useCallback((data: Item[] | null, index: number) => ({
  length: ITEM_HEIGHT,
  offset: ITEM_HEIGHT * index,
  index,
}), [])

<FlatList
  data={items}
  renderItem={renderItem}
  keyExtractor={keyExtractor}
  getItemLayout={getItemLayout}
  initialNumToRender={10}
  maxToRenderPerBatch={10}
  windowSize={5}
  removeClippedSubviews={Platform.OS === 'android'}
  ListEmptyComponent={EmptyState}
/>
```

## New Architecture (TurboModules)

**Codegen Spec:**
```typescript
// NativeCalendar.ts
import type { TurboModule } from 'react-native'
import { TurboModuleRegistry } from 'react-native'

export interface Spec extends TurboModule {
  createEvent(title: string, date: number): Promise<string>
  getEvents(startDate: number, endDate: number): Promise<Event[]>
}

export default TurboModuleRegistry.getEnforcing<Spec>('NativeCalendar')
```

## Expo vs Bare Workflow Decision Tree

```yaml
START: Does the app need custom native modules not in Expo SDK?
├── NO: Use Expo managed workflow
│   ├── Need CI/CD? → Use EAS Build
│   ├── Need OTA updates? → Use EAS Update
│   └── Need push notifications? → Use expo-notifications
├── YES: Can the native module work with expo-dev-client?
│   ├── YES: Use Expo with development builds (expo-dev-client)
│   │   └── Create config plugin if native config needed
│   └── NO: Eject to bare workflow
│       ├── Need Bluetooth/NFC? → Bare + community modules
│       ├── Need custom video codec? → Bare + native module
│       └── Need heavy native SDK (AR/VR)? → Bare workflow required
```

**When to stay in Expo managed:**
- Standard camera, maps, push notifications, in-app purchases
- No custom Kotlin/Swift native modules needed
- Team has limited native iOS/Android experience

**When to eject or use bare workflow:**
- Must integrate a proprietary native SDK (e.g., banking SDK, AR framework)
- Need fine-grained control over Xcode/Gradle build settings
- Performance-critical native code that cannot go through the bridge

## New Architecture Migration Decision

| Condition | Recommendation |
|-----------|---------------|
| RN >= 0.73, greenfield project | Enable New Architecture from the start |
| RN >= 0.73, all deps support new arch | Migrate: enable `newArchEnabled` in gradle.properties / Podfile |
| RN >= 0.73, some deps lack support | Wait or fork unsupported deps; check reactnative.directory |
| RN < 0.72 | Upgrade RN first, then enable new arch |
| Using Expo SDK 50+ | Set `expo.newArchEnabled: true` in app.json |
| Heavy bridge usage with NativeModules | Convert to TurboModules with codegen specs |

## Anti-Patterns

### 1. Over-Bridging: Excessive Native Module Calls

**BAD** - Calling native module on every frame or keystroke:
```typescript
// Calling bridge on every text change - causes jank
const onChangeText = (text: string) => {
  NativeModules.Analytics.trackKeystroke(text) // Bridge call per keystroke!
  setText(text)
}
```

**GOOD** - Batch or debounce native calls:
```typescript
const onChangeText = (text: string) => {
  setText(text)
}
// Debounce analytics to reduce bridge traffic
const onBlur = () => {
  NativeModules.Analytics.trackFieldCompleted(fieldName, text)
}
```

### 2. Ignoring Hermes Engine

**BAD** - Leaving Hermes disabled or not checking it is active:
```javascript
// android/app/build.gradle
hermesEnabled = false  // JSC is slower, uses more memory
```

**GOOD** - Enable Hermes and verify with runtime check:
```javascript
// android/app/build.gradle
hermesEnabled = true

// Verify at runtime
const isHermes = () => !!global.HermesInternal
console.log('Engine:', isHermes() ? 'Hermes' : 'JSC')
```

### 3. Wrong Navigation Pattern (Nesting Without Purpose)

**BAD** - Deeply nested navigators causing performance issues:
```typescript
<Stack.Navigator>
  <Stack.Screen name="TabRoot">
    <Tab.Navigator>
      <Tab.Screen name="HomeStack">
        <Stack.Navigator>      {/* Unnecessary nesting */}
          <Stack.Screen name="HomeTab">
            <Stack.Navigator>  {/* Even more nesting */}
```

**GOOD** - Flat structure with shared screens at root level:
```typescript
<Stack.Navigator>
  <Stack.Screen name="Main" component={MainTabs} />
  <Stack.Screen name="Details" component={DetailsScreen} />
  <Stack.Screen name="Settings" component={SettingsScreen} />
</Stack.Navigator>
// Shared screens live at root stack, not nested inside each tab
```

### 4. Using AsyncStorage for Sensitive Data

**BAD** - Tokens stored in unencrypted AsyncStorage:
```typescript
await AsyncStorage.setItem('auth_token', token)
```

**GOOD** - Use react-native-keychain for sensitive data:
```typescript
await Keychain.setGenericPassword('auth', token, {
  accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
})
```

### 5. Not Memoizing Expensive Computations

**BAD** - Filtering a large list on every render:
```typescript
function UserList({ users, searchQuery }) {
  const filtered = users.filter(u => u.name.includes(searchQuery)) // Runs every render
  return <FlatList data={filtered} ... />
}
```

**GOOD** - Use useMemo to cache the result:
```typescript
function UserList({ users, searchQuery }) {
  const filtered = useMemo(
    () => users.filter(u => u.name.includes(searchQuery)),
    [users, searchQuery]
  )
  return <FlatList data={filtered} ... />
}
```

## Escalation Paths

| Situation | Hand Off To | What to Provide |
|-----------|------------|-----------------|
| FPS drops below 50, jank during scroll or animation | `mobile-performance-optimizer` | Flipper trace, component tree, list item count |
| Startup time > 3s after Hermes enabled | `mobile-performance-optimizer` | Bundle size, require cycle output, startup trace |
| Storing tokens, encryption, cert pinning needed | `mobile-security-specialist` | Current storage method, API endpoints, threat model |
| Jailbreak detection or code obfuscation | `mobile-security-specialist` | Target platforms, compliance requirements |
| Custom native module with complex threading | Native iOS/Android specialist | Bridge spec, platform requirements, threading needs |
| CI/CD pipeline for EAS Build or Fastlane | DevOps / CI specialist | Current build config, target stores, signing certs |

## Tool Commands

**Diagnostics and Info:**
```bash
# Full React Native environment info (RN version, Hermes, platform SDKs)
npx react-native info

# Expo-specific diagnostics
npx expo diagnostics

# Check for outdated dependencies
npx react-native upgrade-helper

# Verify Hermes is active in the bundle
adb logcat | grep -i hermes
```

**Building and Running:**
```bash
# Start Metro bundler with cache reset
npx react-native start --reset-cache

# Run on specific device/simulator
npx react-native run-android --deviceId=<id>
npx react-native run-ios --simulator="iPhone 15 Pro"

# Expo dev build
npx expo run:ios
npx expo run:android
```

**Performance and Debugging:**
```bash
# Bundle size analysis
npx react-native-bundle-visualizer

# Generate Hermes CPU profile
adb shell am broadcast -a com.facebook.react.ACTION_PROFILE_CPU

# Check for require cycles
npx madge --circular src/

# Lint and type check
npx tsc --noEmit
npx eslint src/ --ext .ts,.tsx
```

**EAS Build and Deploy:**
```bash
# Build for internal distribution
eas build --profile preview --platform all

# Submit to app stores
eas submit --platform ios
eas submit --platform android

# OTA update
eas update --branch production --message "Bug fix"
```

## Best Practices

- **Use TypeScript** everywhere with strict mode enabled
- **Memoize callbacks** with useCallback to prevent re-renders
- **Extract styles** to StyleSheet.create outside components
- **Avoid inline styles** and arrow functions in JSX
- **Use Hermes** engine for improved startup and memory
- **Implement error boundaries** for graceful crash handling
- **Test on real devices** regularly during development

## Common Pitfalls

- Creating inline functions in render causing unnecessary re-renders
- Not using getItemLayout for FlatList when item heights are known
- Storing large objects in AsyncStorage (use MMKV instead)
- Missing keyboard handling with KeyboardAvoidingView
- Not cleaning up subscriptions in useEffect
