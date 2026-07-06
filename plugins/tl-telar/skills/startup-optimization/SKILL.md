---
name: "startup-optimization"
description: "Every second of cold start time loses approximately 10% of users. A 4-second startup means 40% of users may abandon your app before seeing content. This skill covers profiling, bundle optimization, lazy loading, and spla"
source_type: "skill"
source_file: "skills/startup-optimization.md"
---

# startup-optimization

Migrated from `skills/startup-optimization.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Optimize Mobile App Cold Start to Under 2 Seconds

Every second of cold start time loses approximately 10% of users. A 4-second startup means 40% of users may abandon your app before seeing content. This skill covers profiling, bundle optimization, lazy loading, and splash screen bridging to cut cold start time dramatically.

## Problem

Eager imports and large bundles cause the JavaScript engine to parse and execute megabytes of code before showing the first screen. Common culprits: importing entire icon libraries, analytics SDKs, and charting libraries at the top level.

```typescript
// BAD: Top-level imports of everything - all parsed at startup
import { Analytics } from '@segment/analytics-react-native';
import { Sentry } from '@sentry/react-native';
import MaterialIcons from 'react-native-vector-icons/MaterialIcons';
import FontAwesome from 'react-native-vector-icons/FontAwesome';
import { Chart } from 'react-native-chart-kit';
import { Camera } from 'react-native-vision-camera';
import { Map } from 'react-native-maps';
import moment from 'moment'; // 300KB+ with all locales
import lodash from 'lodash'; // 70KB+ when not tree-shaken
import { decode } from 'html-entities'; // Rarely used, always loaded

// BAD: All screens imported eagerly in navigator
import HomeScreen from './screens/HomeScreen';
import ProfileScreen from './screens/ProfileScreen';
import SettingsScreen from './screens/SettingsScreen';
import AdminDashboard from './screens/AdminDashboard'; // 99% of users never see this
import OnboardingScreen from './screens/OnboardingScreen'; // Only shown once
import ARScreen from './screens/ARScreen'; // Heavy, rarely used
import VideoEditor from './screens/VideoEditor'; // Imports FFmpeg at top level

const Stack = createNativeStackNavigator();

function App() {
  return (
    <Stack.Navigator>
      <Stack.Screen name="Home" component={HomeScreen} />
      <Stack.Screen name="Profile" component={ProfileScreen} />
      <Stack.Screen name="Settings" component={SettingsScreen} />
      <Stack.Screen name="Admin" component={AdminDashboard} />
      <Stack.Screen name="Onboarding" component={OnboardingScreen} />
      <Stack.Screen name="AR" component={ARScreen} />
      <Stack.Screen name="VideoEditor" component={VideoEditor} />
    </Stack.Navigator>
  );
}

// BAD: Initializing everything synchronously before render
Analytics.setup('key');
Sentry.init({ dsn: '...' });
// App cannot render until all of this completes
```

```typescript
// BAD: Splash screen hides immediately, showing white flash
import * as SplashScreen from 'expo-splash-screen';

function App() {
  const [data, setData] = useState(null);

  useEffect(() => {
    fetchInitialData().then(setData);
    // Splash already gone, user sees blank white screen during fetch
  }, []);

  if (!data) return null; // White screen until data loads

  return <MainApp data={data} />;
}
```

## Solution

### 1. Before/After Profiling Methodology

```typescript
// GOOD: Measure startup time precisely to track improvements
// Add this as the VERY FIRST line in index.js, before any other import
const STARTUP_START = global.performance?.now?.() ?? Date.now();

// In your root App component, measure time to first render
import { useEffect, useRef } from 'react';
import { InteractionManager, PerformanceObserver } from 'react-native';

function App() {
  const mounted = useRef(false);

  useEffect(() => {
    if (!mounted.current) {
      mounted.current = true;

      const startupDuration = (global.performance?.now?.() ?? Date.now()) - STARTUP_START;
      console.log(`[STARTUP] JS ready: ${startupDuration.toFixed(0)}ms`);

      // Measure time to interactive (after animations settle)
      InteractionManager.runAfterInteractions(() => {
        const tti = (global.performance?.now?.() ?? Date.now()) - STARTUP_START;
        console.log(`[STARTUP] Interactive: ${tti.toFixed(0)}ms`);

        // Report to analytics (deferred, not blocking startup)
        reportStartupMetric(tti);
      });
    }
  }, []);

  return <MainApp />;
}

// Track individual phase timings
function measurePhase(name: string, fn: () => Promise<void>): Promise<void> {
  const start = performance.now();
  return fn().then(() => {
    console.log(`[STARTUP] ${name}: ${(performance.now() - start).toFixed(0)}ms`);
  });
}
```

### 2. Hermes Bundle Analysis and Optimization

```bash
# GOOD: Analyze what is in your bundle

# Step 1: Generate the Hermes bundle with source map
npx react-native bundle \
  --platform android \
  --dev false \
  --entry-file index.js \
  --bundle-output /tmp/bundle.js \
  --sourcemap-output /tmp/bundle.js.map

# Step 2: Visualize bundle contents
npx source-map-explorer /tmp/bundle.js /tmp/bundle.js.map
# Opens browser with interactive treemap showing every module's size

# Step 3: Check Hermes bytecode compilation
# Hermes pre-compiles JS to bytecode, so parse time is near-zero
# Verify Hermes is enabled:
# android/app/build.gradle:
#   project.ext.react = [enableHermes: true]
# ios/Podfile:
#   :hermes_enabled => true

# Step 4: Profile with Hermes sampling profiler
npx react-native profile-hermes ./hermes-profile.cpuprofile
# Open in Chrome DevTools > Performance tab
```

```javascript
// metro.config.js - GOOD: Configure Metro for optimal bundle
const { getDefaultConfig } = require('@react-native/metro-config');

const config = getDefaultConfig(__dirname);

module.exports = {
  ...config,
  transformer: {
    ...config.transformer,
    // Enable inline requires - defer module execution until first use
    getTransformOptions: async () => ({
      transform: {
        experimentalImportSupport: true,
        inlineRequires: true, // KEY: Defers require() until first call
        nonInlinedRequires: [
          // Modules that must load eagerly (minimal list)
          'react',
          'react-native',
        ],
      },
    }),
  },
};
```

### 3. Tree Shaking and Dead Code Elimination

```typescript
// GOOD: Import only what you need - tree shaking eliminates the rest

// Instead of: import lodash from 'lodash' (70KB)
import debounce from 'lodash/debounce'; // 1KB
import throttle from 'lodash/throttle'; // 1KB

// Instead of: import moment from 'moment' (300KB with locales)
import { format, parseISO, formatDistanceToNow } from 'date-fns'; // 7KB per function

// Instead of: import { Icon } from 'react-native-vector-icons/MaterialIcons' (all icons)
// Use a custom icon component that loads only used icons
import { createIconSetFromIcoMoon } from 'react-native-vector-icons';
import icoMoonConfig from './selection.json'; // Only your ~50 icons, not 5000+
const CustomIcon = createIconSetFromIcoMoon(icoMoonConfig);

// Instead of: import * as Sentry from '@sentry/react-native'
import { init, captureException } from '@sentry/react-native'; // Named imports only
```

```javascript
// babel.config.js - GOOD: Babel plugins for dead code removal
module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: [
    // Remove console.log in production (saves parse time)
    ['transform-remove-console', { exclude: ['error', 'warn'] }],

    // Tree-shake lodash imports
    'babel-plugin-lodash',

    // Reanimated plugin MUST be last
    'react-native-reanimated/plugin',
  ],
  env: {
    production: {
      plugins: [
        // Remove PropTypes in production
        ['transform-react-remove-prop-types', { removeImport: true }],
      ],
    },
  },
};
```

### 4. Lazy Loading Screens and Heavy Modules

```typescript
// GOOD: Lazy load screens that are not needed on first render
import React, { Suspense, lazy } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

// Only HomeScreen loads at startup - everything else is deferred
import HomeScreen from './screens/HomeScreen';

// Lazy load all secondary screens
const ProfileScreen = lazy(() => import('./screens/ProfileScreen'));
const SettingsScreen = lazy(() => import('./screens/SettingsScreen'));
const AdminDashboard = lazy(() => import('./screens/AdminDashboard'));
const ARScreen = lazy(() => import('./screens/ARScreen'));
const VideoEditor = lazy(() => import('./screens/VideoEditor'));

// Suspense wrapper with loading fallback
function LazyScreen(Component: React.LazyExoticComponent<any>) {
  return function WrappedScreen(props: any) {
    return (
      <Suspense
        fallback={
          <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
            <ActivityIndicator size="large" />
          </View>
        }
      >
        <Component {...props} />
      </Suspense>
    );
  };
}

const Stack = createNativeStackNavigator();

function AppNavigator() {
  return (
    <Stack.Navigator>
      <Stack.Screen name="Home" component={HomeScreen} />
      <Stack.Screen name="Profile" component={LazyScreen(ProfileScreen)} />
      <Stack.Screen name="Settings" component={LazyScreen(SettingsScreen)} />
      <Stack.Screen name="Admin" component={LazyScreen(AdminDashboard)} />
      <Stack.Screen name="AR" component={LazyScreen(ARScreen)} />
      <Stack.Screen name="VideoEditor" component={LazyScreen(VideoEditor)} />
    </Stack.Navigator>
  );
}
```

```typescript
// GOOD: Lazy load heavy modules only when needed
let _cameraModule: typeof import('react-native-vision-camera') | null = null;

async function getCamera() {
  if (!_cameraModule) {
    _cameraModule = await import('react-native-vision-camera');
  }
  return _cameraModule;
}

// GOOD: Defer non-critical initialization
import { InteractionManager } from 'react-native';

function useDefferredInit() {
  useEffect(() => {
    // Phase 1: Critical path only (auth check, initial data)
    const criticalInit = async () => {
      await checkAuthStatus();
      await fetchHomeScreenData();
    };

    criticalInit().then(() => {
      // Phase 2: After first render + interactions settle
      InteractionManager.runAfterInteractions(() => {
        // Analytics - not needed for first render
        import('@segment/analytics-react-native').then(({ Analytics }) => {
          Analytics.setup('key');
        });

        // Error tracking - not needed for first render
        import('@sentry/react-native').then(({ init }) => {
          init({ dsn: '...' });
        });

        // Push notifications - not needed for first render
        import('./services/notifications').then(({ registerForPush }) => {
          registerForPush();
        });

        // Prefetch likely next screens
        import('./screens/ProfileScreen');
      });
    });
  }, []);
}
```

### 5. Splash Screen Bridging

```typescript
// GOOD: Hold native splash until app is fully ready - zero white flash
import * as SplashScreen from 'expo-splash-screen';
import { useCallback, useEffect, useState } from 'react';
import { View, StyleSheet } from 'react-native';
import Animated, { FadeIn } from 'react-native-reanimated';

// Prevent splash from auto-hiding - call BEFORE component renders
SplashScreen.preventAutoHideAsync();

interface AppReadyState {
  fontsLoaded: boolean;
  authChecked: boolean;
  initialDataLoaded: boolean;
}

function App() {
  const [ready, setReady] = useState<AppReadyState>({
    fontsLoaded: false,
    authChecked: false,
    initialDataLoaded: false,
  });

  const isReady = ready.fontsLoaded && ready.authChecked && ready.initialDataLoaded;

  useEffect(() => {
    async function prepare() {
      try {
        // Run critical init in parallel for speed
        await Promise.all([
          loadFonts().then(() => setReady(r => ({ ...r, fontsLoaded: true }))),
          checkAuth().then(() => setReady(r => ({ ...r, authChecked: true }))),
          fetchInitialData().then(() => setReady(r => ({ ...r, initialDataLoaded: true }))),
        ]);
      } catch (e) {
        // Even on error, hide splash and show error UI
        setReady({ fontsLoaded: true, authChecked: true, initialDataLoaded: true });
      }
    }

    prepare();
  }, []);

  // Hide splash screen when layout is ready
  const onLayoutRootView = useCallback(async () => {
    if (isReady) {
      // Small delay ensures the first frame has rendered
      await new Promise(resolve => setTimeout(resolve, 50));
      await SplashScreen.hideAsync();
    }
  }, [isReady]);

  if (!isReady) return null; // Native splash still visible

  return (
    <Animated.View
      style={styles.container}
      onLayout={onLayoutRootView}
      entering={FadeIn.duration(300)} // Smooth transition from splash
    >
      <MainApp />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
});
```

### 6. Flutter Startup Optimization

```dart
// GOOD: Deferred initialization in Flutter
void main() async {
  // Preserve native splash while initializing
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Only initialize what is needed for first frame
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // Defer non-critical init to after first frame
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      // Remove splash after first frame paints
      FlutterNativeSplash.remove();

      // Then initialize everything else
      await _initAnalytics();
      await _initCrashReporting();
      await _initPushNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Use deferred loading for routes
      routes: {
        '/': (_) => const HomeScreen(),
      },
      onGenerateRoute: (settings) {
        // Lazy load heavy screens
        return MaterialPageRoute(
          builder: (_) => _buildDeferredScreen(settings.name),
        );
      },
    );
  }
}

// GOOD: Use deferred imports for heavy features (Dart-specific)
import 'package:heavy_feature/heavy_feature.dart' deferred as heavy;

Future<void> openHeavyFeature(BuildContext context) async {
  // Only downloads/loads the library when user navigates here
  await heavy.loadLibrary();
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => heavy.HeavyFeatureScreen(),
  ));
}
```

## Why This Works

- **Inline requires defer execution**: Instead of executing every `require()` at bundle load time, modules are only initialized when first accessed. This can cut startup JavaScript execution time by 50% or more.
- **Hermes bytecode eliminates parse time**: Hermes pre-compiles JavaScript to bytecode during the build. The engine loads bytecode directly via mmap, skipping the parsing step that V8/JSC must do. This alone can save 500ms+ on mid-range devices.
- **Parallel critical init**: Running font loading, auth check, and initial data fetch concurrently with `Promise.all` instead of sequentially can save 500-1000ms depending on the slowest operation.
- **Splash screen bridging**: The native splash screen stays visible until `onLayout` fires on the root view, guaranteeing the first frame is painted before the splash disappears. No white flash is possible.
- **Lazy screens never load until navigated**: If a user opens the app and only views the home screen, none of the other screen bundles execute. For apps with 20+ screens, this eliminates the majority of startup work.

## Edge Cases & Pitfalls

### Platform-Specific Gotchas

**iOS:**
- iOS imposes a 20-second startup watchdog. If your app does not call `UIApplicationMain` within 20 seconds, the OS kills it. Keep native initialization fast.
- `Launch Storyboard` caching: iOS caches the launch screen. If you change it, users may still see the old one until they restart the device.

**Android:**
- Cold start includes process creation + VM init. Use `<application android:largeHeap="true">` only if truly needed, as it slows VM allocation.
- Hermes performs best with `enableProguardInReleaseBuilds = true` to strip Java dead code.
- Android 12+ has a dedicated `SplashScreen` API. Migrate from legacy splash implementations.

### Common Mistakes

- **Measuring in debug mode**: Debug builds are 5-10x slower than release. Always profile with `--variant=release` on Android or a release scheme on iOS.
- **Forgetting inline requires**: Without `inlineRequires: true` in Metro config, every `import` at the top of a file executes immediately. This is the single highest-impact optimization.
- **Over-lazy loading**: Do not lazy load the home screen or screens in the critical path. Lazy loading adds latency to first navigation.
- **Blocking the main thread in native code**: Native module initialization (e.g., camera, maps) on the main thread blocks rendering. Use `@ReactModule(needsEagerInit = false)` on Android.

## Verification

```bash
# Measure bundle size
ls -lh android/app/build/generated/assets/createBundleReleaseJsAndAssets/index.android.bundle

# Profile startup on Android
adb shell am start -W com.myapp/.MainActivity
# Look for TotalTime in output

# Profile startup on iOS
# Xcode > Product > Profile > Time Profiler
# Filter to first 3 seconds

# Source map analysis
npx source-map-explorer /tmp/bundle.js /tmp/bundle.js.map --html /tmp/bundle-report.html
open /tmp/bundle-report.html
```

- [ ] Cold start measured in release mode is under 2 seconds
- [ ] `inlineRequires: true` is set in metro.config.js
- [ ] Hermes is enabled on both iOS and Android
- [ ] Source map explorer shows no unexpectedly large modules
- [ ] Non-critical SDKs (analytics, crash reporting) initialize after first render
- [ ] Splash screen persists until app content is painted (no white flash)
- [ ] Bundle size has not regressed (track in CI)

## References

- [React Native Performance Overview](https://reactnative.dev/docs/performance)
- [Hermes Engine](https://hermesengine.dev/)
- [Metro Inline Requires](https://metrobundler.dev/docs/configuration/#inline-requires)
- [Expo SplashScreen API](https://docs.expo.dev/versions/latest/sdk/splash-screen/)
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [source-map-explorer](https://github.com/danvk/source-map-explorer)
- [Android App Startup Time](https://developer.android.com/topic/performance/vitals/launch-time)
