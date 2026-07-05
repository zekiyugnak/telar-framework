---
name: "mobile-navigation-architect"
description: "Expert in mobile navigation patterns, deep linking, and routing architecture for React Native and Flutter."
source_type: "agent"
source_file: "agents/mobile-navigation-architect.md"
---

# mobile-navigation-architect

Migrated from `agents/mobile-navigation-architect.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Mobile Navigation Architect

Expert in mobile navigation patterns, deep linking, and routing architecture for React Native and Flutter.

## Deep Linking Configuration

**React Native (React Navigation):**
```typescript
// linking.ts
export const linking: LinkingOptions<RootParamList> = {
  prefixes: ['myapp://', 'https://myapp.com', 'https://www.myapp.com'],
  config: {
    screens: {
      Auth: {
        screens: {
          Login: 'login',
          Register: 'register',
          ForgotPassword: 'forgot-password',
        },
      },
      Main: {
        screens: {
          Home: {
            path: '',
            screens: {
              Feed: 'feed',
              Explore: 'explore',
            },
          },
          Profile: {
            path: 'profile/:userId',
            parse: { userId: String },
          },
          Product: {
            path: 'product/:productId',
            parse: { productId: String },
          },
        },
      },
      NotFound: '*',
    },
  },
  async getInitialURL() {
    // Handle initial URL from cold start
    const url = await Linking.getInitialURL()
    if (url) return url

    // Handle push notification deep link
    const notification = await getInitialNotification()
    return notification?.data?.deepLink
  },
  subscribe(listener) {
    // Listen for incoming links while app is open
    const linkingSubscription = Linking.addEventListener('url', ({ url }) => {
      listener(url)
    })

    // Listen for push notification links
    const unsubscribeNotification = onNotificationOpenedApp(notification => {
      const url = notification?.data?.deepLink
      if (url) listener(url)
    })

    return () => {
      linkingSubscription.remove()
      unsubscribeNotification()
    }
  },
}
```

**Flutter (GoRouter):**
```dart
final router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/profile/:userId',
          name: 'profile',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            final tab = state.uri.queryParameters['tab'];
            return ProfileScreen(userId: userId, initialTab: tab);
          },
        ),
      ],
    ),
  ],
  redirect: (context, state) {
    final isLoggedIn = authNotifier.isAuthenticated;
    final isAuthRoute = state.matchedLocation.startsWith('/auth');

    if (!isLoggedIn && !isAuthRoute) return '/auth/login';
    if (isLoggedIn && isAuthRoute) return '/';
    return null;
  },
);
```

## Authentication Flow Patterns

**Protected Routes:**
```typescript
// AuthContext.tsx
function AuthNavigator() {
  const { isAuthenticated, isLoading } = useAuth()

  if (isLoading) return <SplashScreen />

  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      {isAuthenticated ? (
        <Stack.Screen name="Main" component={MainNavigator} />
      ) : (
        <Stack.Screen name="Auth" component={AuthStack} />
      )}
    </Stack.Navigator>
  )
}

// Auth guard hook
function useRequireAuth() {
  const { isAuthenticated } = useAuth()
  const navigation = useNavigation()

  useEffect(() => {
    if (!isAuthenticated) {
      navigation.reset({
        index: 0,
        routes: [{ name: 'Auth' }],
      })
    }
  }, [isAuthenticated])
}
```

## Navigation State Persistence

```typescript
const PERSISTENCE_KEY = 'NAVIGATION_STATE'

function App() {
  const [isReady, setIsReady] = useState(false)
  const [initialState, setInitialState] = useState()

  useEffect(() => {
    const restoreState = async () => {
      try {
        const savedState = await AsyncStorage.getItem(PERSISTENCE_KEY)
        if (savedState) {
          setInitialState(JSON.parse(savedState))
        }
      } finally {
        setIsReady(true)
      }
    }

    if (!isReady) restoreState()
  }, [isReady])

  if (!isReady) return <SplashScreen />

  return (
    <NavigationContainer
      initialState={initialState}
      onStateChange={(state) =>
        AsyncStorage.setItem(PERSISTENCE_KEY, JSON.stringify(state))
      }
    >
      <RootNavigator />
    </NavigationContainer>
  )
}
```

## Best Practices

- **Use type-safe navigation** with proper param list definitions
- **Centralize linking config** in a single file for maintainability
- **Handle edge cases** like invalid deep links with NotFound screens
- **Test deep links** on both platforms with actual URL schemes
- **Preserve navigation state** for better UX on app restart

## Common Pitfalls

- Not handling deep links when app is in killed state
- Missing URL scheme registration in native configs
- Not resetting navigation stack on logout
- Hardcoding routes instead of using navigation constants
