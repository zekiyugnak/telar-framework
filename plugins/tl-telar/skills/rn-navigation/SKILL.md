---
name: "rn-navigation"
description: "Navigation state persisting after logout is one of the most common security bugs in React Native apps. Users sign out but the previous user's screens, data, and scroll positions remain in the navigation stack. This skill"
source_type: "skill"
source_file: "skills/rn-navigation.md"
---

# rn-navigation

Migrated from `skills/rn-navigation.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Fix Navigation State Leaks on Logout in React Navigation

Navigation state persisting after logout is one of the most common security bugs in React Native apps. Users sign out but the previous user's screens, data, and scroll positions remain in the navigation stack. This skill covers auth flows, modal stacks, tab persistence, reset patterns, type-safe navigation, and deep linking.

## Problem

Without proper navigation reset on logout, the previous user's data leaks into the next session. Screens in tab navigators retain stale state, back buttons reveal previous user's screens, and cached route params expose sensitive data.

```typescript
// BAD: Navigating to login screen on logout without resetting state
// This leaves the entire previous navigation history intact
function ProfileScreen({ navigation }: ProfileProps) {
  const handleLogout = async () => {
    await AsyncStorage.removeItem('token');
    // WRONG: This pushes login ON TOP of existing stack
    // Previous user's screens are still underneath
    navigation.navigate('Login');
  };

  return <Button title="Logout" onPress={handleLogout} />;
}

// BAD: Conditional rendering without state-driven auth
function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);

  return (
    <NavigationContainer>
      <Stack.Navigator>
        {/* WRONG: Both stacks are always defined, navigation state persists */}
        <Stack.Screen name="Login" component={LoginScreen} />
        <Stack.Screen name="Home" component={HomeScreen} />
        <Stack.Screen name="Profile" component={ProfileScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}

// BAD: Tabs without unmountOnBlur keep stale data across user sessions
<Tab.Navigator>
  <Tab.Screen name="Feed" component={FeedScreen} />
  <Tab.Screen name="Messages" component={MessagesScreen} />
</Tab.Navigator>
```

## Solution

Use conditional stack rendering driven by auth state. When the token changes, React Navigation automatically resets the entire navigation tree. Combine with proper type safety, modal stacks, and deep linking.

### Type-Safe Navigation Setup

```typescript
// GOOD: Define all param lists with strict types
// src/navigation/types.ts
export type AuthStackParamList = {
  Login: undefined;
  Register: undefined;
  ForgotPassword: { email?: string };
};

export type MainTabParamList = {
  Home: undefined;
  Search: { query?: string };
  Profile: undefined;
  Notifications: undefined;
};

export type HomeStackParamList = {
  HomeFeed: undefined;
  PostDetail: { postId: string; authorId: string };
  UserProfile: { userId: string };
};

export type RootStackParamList = {
  MainTabs: NavigatorScreenParams<MainTabParamList>;
  Modal: { screen: string };
  ImageViewer: { uri: string; title?: string };
};

// Merge all param lists for global type checking
declare global {
  namespace ReactNavigation {
    interface RootParamList extends RootStackParamList {}
  }
}
```

### Auth-Driven Stack Switching

```typescript
// GOOD: Auth state drives which navigator renders
// src/navigation/RootNavigator.tsx
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useAuth } from '../hooks/useAuth';

const AuthStack = createNativeStackNavigator<AuthStackParamList>();
const RootStack = createNativeStackNavigator<RootStackParamList>();

function AuthNavigator() {
  return (
    <AuthStack.Navigator screenOptions={{ headerShown: false }}>
      <AuthStack.Screen name="Login" component={LoginScreen} />
      <AuthStack.Screen name="Register" component={RegisterScreen} />
      <AuthStack.Screen name="ForgotPassword" component={ForgotPasswordScreen} />
    </AuthStack.Navigator>
  );
}

function MainNavigator() {
  return (
    <RootStack.Navigator>
      <RootStack.Screen
        name="MainTabs"
        component={MainTabNavigator}
        options={{ headerShown: false }}
      />
      {/* Modal screens presented over tabs */}
      <RootStack.Group screenOptions={{ presentation: 'modal' }}>
        <RootStack.Screen name="Modal" component={ModalScreen} />
      </RootStack.Group>
      <RootStack.Group screenOptions={{ presentation: 'transparentModal' }}>
        <RootStack.Screen
          name="ImageViewer"
          component={ImageViewerScreen}
          options={{ headerShown: false }}
        />
      </RootStack.Group>
    </RootStack.Navigator>
  );
}

// When token becomes null, React Navigation unmounts MainNavigator
// and mounts AuthNavigator - ALL navigation state is destroyed
export function RootNavigator() {
  const { token, isLoading } = useAuth();

  if (isLoading) return <SplashScreen />;

  return token ? <MainNavigator /> : <AuthNavigator />;
}
```

### Tab Navigator with Persistence

```typescript
// GOOD: Tab navigator with controlled persistence
// src/navigation/MainTabNavigator.tsx
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';

const Tab = createBottomTabNavigator<MainTabParamList>();

function MainTabNavigator() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        // Keep tab screens mounted to preserve scroll position and data
        // This is safe because the ENTIRE tab navigator unmounts on logout
        unmountOnBlur: false,
        tabBarIcon: ({ focused, color, size }) => {
          const iconMap: Record<string, string> = {
            Home: focused ? 'home' : 'home-outline',
            Search: focused ? 'search' : 'search-outline',
            Profile: focused ? 'person' : 'person-outline',
            Notifications: focused ? 'notifications' : 'notifications-outline',
          };
          return <Ionicons name={iconMap[route.name]} size={size} color={color} />;
        },
        headerShown: false,
      })}
    >
      <Tab.Screen name="Home" component={HomeStack} />
      <Tab.Screen name="Search" component={SearchScreen} />
      <Tab.Screen name="Notifications" component={NotificationsScreen} />
      <Tab.Screen name="Profile" component={ProfileScreen} />
    </Tab.Navigator>
  );
}
```

### Navigation Container with Deep Linking

```typescript
// GOOD: Full NavigationContainer setup with deep linking and state persistence
// src/navigation/App.tsx
import { NavigationContainer, LinkingOptions } from '@react-navigation/native';
import AsyncStorage from '@react-native-async-storage/async-storage';

const linking: LinkingOptions<RootStackParamList> = {
  prefixes: ['myapp://', 'https://myapp.com'],
  config: {
    screens: {
      MainTabs: {
        screens: {
          Home: {
            screens: {
              HomeFeed: '',
              PostDetail: 'post/:postId',
              UserProfile: 'user/:userId',
            },
          },
          Search: 'search',
          Profile: 'profile',
        },
      },
      Modal: 'modal/:screen',
      ImageViewer: 'image',
    },
  },
  // Handle incoming URLs when app is closed
  async getInitialURL() {
    const url = await Linking.getInitialURL();
    if (url != null) return url;
    // Check for push notification deep link
    const notification = await getInitialNotification();
    return notification?.data?.url;
  },
};

// Optional: persist navigation state across restarts (dev only)
const PERSISTENCE_KEY = 'NAVIGATION_STATE_V1';

export function App() {
  const [isReady, setIsReady] = useState(__DEV__ ? false : true);
  const [initialState, setInitialState] = useState();

  useEffect(() => {
    if (!__DEV__) return;
    AsyncStorage.getItem(PERSISTENCE_KEY)
      .then((saved) => saved ? setInitialState(JSON.parse(saved)) : undefined)
      .finally(() => setIsReady(true));
  }, []);

  if (!isReady) return null;

  return (
    <NavigationContainer
      linking={linking}
      initialState={__DEV__ ? initialState : undefined}
      onStateChange={(state) => {
        if (__DEV__) {
          AsyncStorage.setItem(PERSISTENCE_KEY, JSON.stringify(state));
        }
      }}
      fallback={<LoadingIndicator />}
    >
      <RootNavigator />
    </NavigationContainer>
  );
}
```

### Explicit Reset for Edge Cases

```typescript
// GOOD: For cases where you need manual reset (e.g., force logout from API 401)
import { CommonActions } from '@react-navigation/native';

function useForceLogout() {
  const navigation = useNavigation();

  return useCallback(() => {
    // Clear all auth state first
    queryClient.clear();
    useAuthStore.getState().clearToken();

    // Then reset navigation to auth stack root
    navigation.dispatch(
      CommonActions.reset({
        index: 0,
        routes: [{ name: 'Login' }],
      })
    );
  }, [navigation]);
}
```

## Why This Works

- **Conditional rendering destroys state**: When the auth token changes from non-null to null, React unmounts `MainNavigator` entirely. React Navigation's internal state (screen stack, params, scroll positions) is garbage collected. No manual cleanup needed.
- **Type-safe params prevent runtime crashes**: `RootStackParamList` enforces that `PostDetail` always receives `postId` and `authorId`. TypeScript catches missing params at compile time, not in production.
- **Modal groups isolate presentation**: `presentation: 'modal'` and `'transparentModal'` render screens over the current stack without pushing onto it. This matches native iOS/Android modal behavior.
- **Deep linking maps URL segments to screens**: The nested `config.screens` object mirrors the navigator hierarchy. React Navigation parses `/post/abc123` and navigates to `PostDetail` with `{ postId: 'abc123' }` automatically.

## Edge Cases & Pitfalls

### Platform-Specific Gotchas

**iOS:**
- Universal links require an `apple-app-site-association` file hosted at `https://yourdomain.com/.well-known/apple-app-site-association` with the correct `appID` (TeamID.BundleID).
- `presentation: 'modal'` uses iOS native card presentation. On iPad, this defaults to form sheet style unless you set `modalPresentationStyle: 'fullScreen'`.
- Swipe-back gesture can conflict with drawer navigators. Use `gestureEnabled: false` on screens where this causes issues.

**Android:**
- Deep link intent filters in `AndroidManifest.xml` must include `autoVerify="true"` for App Links.
- The hardware back button pops the current screen. Override with `BackHandler` if you need custom behavior on specific screens.
- `transparentModal` requires `animation: 'fade'` on Android to avoid a flash of white background.

### Common Mistakes

- **Using `navigation.navigate('Login')` for logout**: This pushes Login on the stack. The previous user's Home, Profile, etc. are still there. Always use conditional rendering or `CommonActions.reset`.
- **Forgetting to type `useNavigation`**: The generic `useNavigation()` has no param type checking. Use `useNavigation<NativeStackNavigationProp<RootStackParamList>>()` or rely on the global `ReactNavigation.RootParamList` declaration.
- **Deep link testing only in dev**: Deep links behave differently when the app is cold-started vs. already running. Test both scenarios on physical devices.
- **Tab state saving without version keys**: If you persist navigation state, always include a version key (`NAVIGATION_STATE_V1`). Schema changes between app versions will crash on restore.

## Verification

```bash
# Test deep linking on iOS simulator
npx uri-scheme open "myapp://post/abc123" --ios

# Test deep linking on Android emulator
adb shell am start -W -a android.intent.action.VIEW -d "myapp://post/abc123" com.yourapp

# Verify universal links (iOS)
xcrun simctl openurl booted "https://myapp.com/post/abc123"
```

- [ ] Sign in as User A, navigate to Profile tab, sign out. Verify no User A data visible.
- [ ] Sign in as User B immediately after. Verify all tabs show fresh state.
- [ ] Kill the app while signed in. Cold-start from a deep link. Verify correct screen loads.
- [ ] Open a modal, rotate device, dismiss. Verify no navigation state corruption.
- [ ] Test `CommonActions.reset` from a deeply nested screen (3+ levels deep).

## References

- [React Navigation Auth Flow](https://reactnavigation.org/docs/auth-flow)
- [React Navigation Deep Linking](https://reactnavigation.org/docs/deep-linking)
- [React Navigation TypeScript](https://reactnavigation.org/docs/typescript)
- [React Navigation Modal](https://reactnavigation.org/docs/modal)
- [Apple Universal Links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
- [Android App Links](https://developer.android.com/training/app-links)
