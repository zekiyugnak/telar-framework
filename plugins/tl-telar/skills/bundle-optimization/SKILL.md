---
name: "bundle-optimization"
description: "A 25MB+ React Native bundle causes App Store \"large download\" warnings on cellular, slow install times, and user abandonment. This skill covers Metro bundler configuration, lazy loading, asset optimization, and dependenc"
source_type: "skill"
source_file: "skills/bundle-optimization.md"
---

# bundle-optimization

Migrated from `skills/bundle-optimization.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Optimize Bundle Size to Eliminate Store Warnings and Slow Downloads

A 25MB+ React Native bundle causes App Store "large download" warnings on cellular, slow install times, and user abandonment. This skill covers Metro bundler configuration, lazy loading, asset optimization, and dependency auditing to bring bundles under control.

## Problem

Unoptimized bundles ship entire libraries, uncompressed assets, and dead code to every user.

```typescript
// BAD: App.tsx - every screen and library loaded upfront
import _ from 'lodash';
import moment from 'moment';
import 'moment/locale/de';
import 'moment/locale/fr';
import 'moment/locale/es';
import 'moment/locale/ja';
import { Chart } from 'react-native-chart-kit';
import { Camera } from 'react-native-camera';
import { MapView } from 'react-native-maps';
import PDFViewer from 'react-native-pdf';

import HomeScreen from './screens/HomeScreen';
import ProfileScreen from './screens/ProfileScreen';
import SettingsScreen from './screens/SettingsScreen';
import AnalyticsScreen from './screens/AnalyticsScreen';
import CameraScreen from './screens/CameraScreen';
import MapScreen from './screens/MapScreen';
import DocumentScreen from './screens/DocumentScreen';
import AdminDashboard from './screens/AdminDashboard';

// Result: 25MB bundle
// - lodash full import: +600KB
// - moment with all locales: +400KB
// - All screens loaded even if user never visits them
// - Full-resolution PNGs at 3x for all density buckets
// - Camera/Map native modules initialized at startup
```

```javascript
// BAD: metro.config.js - no optimization configured
module.exports = {
  // Default config with no tree shaking, no console stripping,
  // no inline requires. Every module loaded eagerly at startup.
};
```

```text
// BAD: assets/ directory
assets/
  hero-background.png      (2.4MB - uncompressed PNG at 3000x2000)
  onboarding-1.png         (1.8MB)
  onboarding-2.png         (1.6MB)
  onboarding-3.png         (1.5MB)
  product-placeholder.png  (800KB)
  icons/                   (200+ individual PNGs instead of icon font)
```

## Solution

### 1. Metro Bundler Configuration for Tree Shaking

```javascript
// GOOD: metro.config.js - optimized for production
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

const defaultConfig = getDefaultConfig(__dirname);

const config = {
  transformer: {
    minifierPath: 'metro-minify-terser',
    minifierConfig: {
      compress: {
        drop_console: true,      // Remove console.log in production
        drop_debugger: true,     // Remove debugger statements
        pure_funcs: [
          'console.log',
          'console.info',
          'console.debug',
          'console.warn',
        ],
        passes: 2,               // Run compression twice for better results
      },
      mangle: {
        toplevel: true,          // Mangle top-level variable names
      },
    },
    // Enable inline requires for faster startup
    getTransformOptions: async () => ({
      transform: {
        experimentalImportSupport: true,
        inlineRequires: true,     // Defer module evaluation until first use
        nonInlinedRequires: [
          // Keep React/RN core eager-loaded
          'React',
          'react',
          'react-native',
        ],
      },
    }),
  },
  resolver: {
    // Prefer .native.js > .ios.js/.android.js > .js
    sourceExts: ['jsx', 'js', 'ts', 'tsx', 'json'],
    // Block test files from production bundle
    blockList: [
      /.*\/__tests__\/.*/,
      /.*\.test\.(js|ts|tsx)$/,
      /.*\.spec\.(js|ts|tsx)$/,
      /.*\.stories\.(js|ts|tsx)$/,
      /.*__mocks__\/.*/,
    ],
  },
};

module.exports = mergeConfig(defaultConfig, config);
```

### 2. Lazy Loading with React.lazy and Dynamic Imports

```typescript
// GOOD: App.tsx - lazy load heavy screens
import React, { Suspense, lazy } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

// Eagerly load lightweight, frequently-visited screens
import HomeScreen from './screens/HomeScreen';
import ProfileScreen from './screens/ProfileScreen';

// Lazy load heavy screens only when navigated to
const AnalyticsScreen = lazy(() => import('./screens/AnalyticsScreen'));
const CameraScreen = lazy(() => import('./screens/CameraScreen'));
const MapScreen = lazy(() => import('./screens/MapScreen'));
const DocumentScreen = lazy(() => import('./screens/DocumentScreen'));
const AdminDashboard = lazy(() => import('./screens/AdminDashboard'));

// Reusable loading fallback
function ScreenLoader() {
  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
      <ActivityIndicator size="large" />
    </View>
  );
}

// Wrapper to add Suspense boundary per screen
function LazyScreen({ component: Component, ...props }: any) {
  return (
    <Suspense fallback={<ScreenLoader />}>
      <Component {...props} />
    </Suspense>
  );
}

const Stack = createNativeStackNavigator();

export default function App() {
  return (
    <NavigationContainer>
      <Stack.Navigator>
        <Stack.Screen name="Home" component={HomeScreen} />
        <Stack.Screen name="Profile" component={ProfileScreen} />
        <Stack.Screen name="Analytics">
          {(props) => <LazyScreen component={AnalyticsScreen} {...props} />}
        </Stack.Screen>
        <Stack.Screen name="Camera">
          {(props) => <LazyScreen component={CameraScreen} {...props} />}
        </Stack.Screen>
        <Stack.Screen name="Map">
          {(props) => <LazyScreen component={MapScreen} {...props} />}
        </Stack.Screen>
        <Stack.Screen name="Documents">
          {(props) => <LazyScreen component={DocumentScreen} {...props} />}
        </Stack.Screen>
        <Stack.Screen name="Admin">
          {(props) => <LazyScreen component={AdminDashboard} {...props} />}
        </Stack.Screen>
      </Stack.Navigator>
    </NavigationContainer>
  );
}
```

```typescript
// GOOD: Conditional feature loading
// Only load analytics SDK in production
async function initAnalytics() {
  if (__DEV__) return;
  const { Analytics } = await import('@segment/analytics-react-native');
  const analytics = new Analytics({ writeKey: 'PROD_KEY' });
  return analytics;
}

// Only load admin tools for admin users
async function loadAdminTools(userRole: string) {
  if (userRole !== 'admin') return null;
  const adminModule = await import('./features/admin');
  return adminModule;
}
```

### 3. Import Optimization and Dependency Replacement

```typescript
// GOOD: Cherry-pick imports instead of pulling entire libraries

// Instead of: import _ from 'lodash' (+600KB)
import debounce from 'lodash/debounce';
import groupBy from 'lodash/groupBy';

// Instead of: import moment from 'moment' (+400KB)
// Use date-fns (tree-shakeable, ~30KB for common operations)
import { format, parseISO, differenceInDays } from 'date-fns';

// Instead of: import { v4 as uuid } from 'uuid' (+30KB)
// Use React Native's built-in or a lightweight alternative
import 'react-native-get-random-values';
import { nanoid } from 'nanoid/non-secure'; // 130 bytes
```

```javascript
// GOOD: babel.config.js - transform imports to cherry-pick automatically
module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: [
    // Automatically transform lodash imports to cherry-picked versions
    'babel-plugin-lodash',
    // Transform barrel imports to direct file imports
    ['babel-plugin-transform-imports', {
      'lodash': {
        transform: 'lodash/${member}',
        preventFullImport: true,
      },
      '@mui/icons-material': {
        transform: '@mui/icons-material/${member}',
        preventFullImport: true,
      },
    }],
  ],
};
```

### 4. Image and Asset Optimization

```bash
# GOOD: Convert PNGs to WebP (70-80% size reduction)
# Install cwebp: brew install webp

# Batch convert all PNGs to WebP
for file in assets/images/*.png; do
  cwebp -q 80 "$file" -o "${file%.png}.webp"
done

# For photos/complex images: use WebP
cwebp -q 80 hero-background.png -o hero-background.webp
# Result: 2.4MB PNG -> 380KB WebP

# For simple icons/illustrations: use SVG
# Replace 200+ icon PNGs with a single icon font or SVG components
```

```typescript
// GOOD: Use react-native-svg for vector icons instead of PNG sprites
// Saves hundreds of KB compared to density-bucketed PNGs
import Svg, { Path } from 'react-native-svg';

function SearchIcon({ size = 24, color = '#000' }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <Path
        d="M21 21L15 15M17 10C17 13.866 13.866 17 10 17C6.134 17 3 13.866 3 10C3 6.134 6.134 3 10 3C13.866 3 17 6.134 17 10Z"
        stroke={color}
        strokeWidth={2}
        strokeLinecap="round"
      />
    </Svg>
  );
}

// GOOD: Use WebP with density-aware loading
import { Image, PixelRatio } from 'react-native';

// React Native automatically selects @1x/@2x/@3x based on device
// Place optimized WebP files in:
//   assets/hero@1x.webp (95KB)
//   assets/hero@2x.webp (190KB)
//   assets/hero@3x.webp (380KB)
// vs original hero.png at 2.4MB

function HeroImage() {
  return (
    <Image
      source={require('./assets/hero.webp')}
      style={{ width: 375, height: 250 }}
      resizeMode="cover"
    />
  );
}
```

### 5. Analyzing Bundle and Removing Dead Weight

```bash
# GOOD: Analyze bundle contents visually
npx react-native-bundle-visualizer

# Generate bundle with source map for detailed analysis
npx react-native bundle \
  --platform ios \
  --dev false \
  --entry-file index.js \
  --bundle-output /tmp/ios-bundle.js \
  --sourcemap-output /tmp/ios-bundle.js.map

# Analyze with source-map-explorer
npx source-map-explorer /tmp/ios-bundle.js /tmp/ios-bundle.js.map

# Find unused dependencies
npx depcheck --ignores="@types/*,babel-*,metro-*"

# Check individual package sizes before adding
npx bundle-phobia-cli lodash   # Shows lodash is 71.5KB min+gzip
npx bundle-phobia-cli date-fns # Shows date-fns is 6.9KB for format()
```

```json
// GOOD: package.json - audit and prune
// Before: 45 dependencies, 25MB bundle
// After:  28 dependencies, 9MB bundle
{
  "scripts": {
    "analyze": "npx react-native-bundle-visualizer",
    "analyze:ios": "npx react-native-bundle-visualizer --platform ios",
    "analyze:android": "npx react-native-bundle-visualizer --platform android",
    "depcheck": "npx depcheck --ignores='@types/*,babel-*,metro-*,react-native-*'",
    "bundle:size": "npx react-native bundle --platform ios --dev false --entry-file index.js --bundle-output /tmp/bundle.js && ls -lh /tmp/bundle.js"
  }
}
```

### 6. Flutter-Specific Bundle Optimization

```dart
// GOOD: Deferred loading for heavy features in Flutter
import 'package:heavy_charts/heavy_charts.dart' deferred as charts;

class AnalyticsPage extends StatelessWidget {
  Future<void> _loadCharts() async {
    await charts.loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadCharts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CircularProgressIndicator();
        }
        return charts.ChartWidget(data: myData);
      },
    );
  }
}
```

```yaml
# GOOD: flutter build with tree shaking and split debug info
# Build command for release APK with size optimization
# flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info

# build.yaml - configure tree shaking
# flutter build appbundle --release --tree-shake-icons
```

```bash
# Flutter: Analyze app size
flutter build apk --analyze-size
flutter build ipa --analyze-size

# Output shows breakdown by package, asset, and native code
```

## Why This Works

- **Inline requires** defer module evaluation: instead of executing all modules at import time, Metro wraps them in functions and calls them on first use. This reduces both bundle parse time and memory footprint at startup.
- **Tree shaking via cherry-picked imports** prevents bundlers from including unused library code. `import debounce from 'lodash/debounce'` pulls in 2KB instead of lodash's full 600KB.
- **WebP compression** uses both lossy and lossless algorithms that outperform PNG and JPEG by 25-35% at equivalent visual quality. Android supports WebP natively; iOS supports it since iOS 14.
- **Console stripping** removes `console.log` calls that are serialized as strings in the bundle and cause bridge traffic on the old architecture.
- **Blocking test files** via Metro resolver prevents test utilities, mocks, and fixture data from appearing in production bundles.

## Edge Cases & Pitfalls

### Platform-Specific Gotchas

**iOS:**
- WebP support requires iOS 14+. If you support iOS 13, provide PNG fallbacks
- App Store "over 200MB" cellular download warning applies to the compressed IPA size, not the raw bundle
- Bitcode (now deprecated in Xcode 14+) used to inflate upload size but no longer applies

**Android:**
- Use `--split-per-abi` to generate separate APKs per architecture (arm64-v8a, armeabi-v7a, x86_64), cutting each APK size roughly in half
- Android App Bundle (AAB) format automatically handles density-based asset delivery
- ProGuard/R8 minification applies to Java/Kotlin native code but not the JS bundle

### Common Mistakes

- **Forgetting to analyze after dependency updates** - a single new dependency can add 500KB+. Run bundle analysis in CI on every PR.
- **Using `require()` for images inside loops** - Metro cannot statically analyze dynamic requires, so these images will not be included in the bundle.
- **Removing `react-native` from `nonInlinedRequires`** - this breaks because RN expects core modules to be eagerly available.
- **Over-aggressive lazy loading** - lazy loading the home screen or login screen adds a visible loading spinner on every app open. Only lazy load screens accessed by less than 30% of sessions.

## Verification

```bash
# 1. Measure baseline bundle size
npx react-native bundle --platform ios --dev false \
  --entry-file index.js --bundle-output /tmp/before.js
ls -lh /tmp/before.js

# 2. Apply optimizations, then measure again
npx react-native bundle --platform ios --dev false \
  --entry-file index.js --bundle-output /tmp/after.js
ls -lh /tmp/after.js

# 3. Visual comparison
npx react-native-bundle-visualizer --platform ios

# 4. Check for unused deps
npx depcheck
```

- [ ] Bundle size reduced below 15MB (ideally under 10MB)
- [ ] No App Store / Play Store size warnings on submission
- [ ] All screens still render correctly after lazy loading changes
- [ ] Startup time has not regressed (inline requires should improve it)
- [ ] CI pipeline includes bundle size check with a threshold alert

## References

- [Metro Bundler Configuration](https://metrobundler.dev/docs/configuration/)
- [React Native Performance - Bundle Size](https://reactnative.dev/docs/performance)
- [react-native-bundle-visualizer](https://github.com/IjzerenHein/react-native-bundle-visualizer)
- [WebP Image Format](https://developers.google.com/speed/webp)
- [Flutter App Size Analysis](https://docs.flutter.dev/perf/app-size)
- [Apple App Store Size Limits](https://developer.apple.com/help/app-store-connect/reference/maximum-build-file-sizes/)
