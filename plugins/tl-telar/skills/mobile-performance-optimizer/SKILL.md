---
name: "mobile-performance-optimizer"
description: "Expert in mobile app performance profiling, optimization, and achieving smooth 60fps experiences."
source_type: "agent"
source_file: "agents/mobile-performance-optimizer.md"
---

# mobile-performance-optimizer

Migrated from `agents/mobile-performance-optimizer.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Mobile Performance Optimizer

Expert in mobile app performance profiling, optimization, and achieving smooth 60fps experiences.

## Performance Metric Thresholds

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| **Time to Interactive (TTI)** | < 2s | 2-4s | > 4s |
| **FPS (scrolling/animation)** | >= 58 | 50-58 | < 50 |
| **App Memory (foreground)** | < 150MB | 150-250MB | > 250MB |
| **JS Bundle Size (RN)** | < 10MB | 10-15MB | > 15MB |
| **App Binary Size (Flutter)** | < 15MB | 15-25MB | > 25MB |
| **Cold Start (Android)** | < 1.5s | 1.5-3s | > 3s |
| **Cold Start (iOS)** | < 1s | 1-2s | > 2s |
| **API Response Render** | < 500ms | 500ms-1s | > 1s |
| **Image Load (cached)** | < 100ms | 100-300ms | > 300ms |
| **JS Thread Usage (RN)** | < 60% | 60-80% | > 80% |

## Profiling Workflow Decision Tree

```yaml
START: What platform and framework?
├── React Native
│   ├── JS thread slow? → Flipper Hermes Profiler
│   │   └── Identify hot functions → optimize or move to native
│   ├── UI thread slow? → React DevTools Profiler
│   │   └── Find re-renders → add memo/useMemo/useCallback
│   ├── Network slow? → Flipper Network Plugin
│   │   └── Check payload size, caching headers
│   └── Memory growing? → Flipper + Chrome DevTools heap snapshot
│       └── Find retained objects → fix cleanup in useEffect
├── Flutter
│   ├── Frame drops? → Dart DevTools Timeline (profile mode)
│   │   ├── Build phase slow → extract widgets, add const
│   │   ├── Paint phase slow → add RepaintBoundary
│   │   └── Shader compilation jank → warm up shaders or use Impeller
│   ├── Memory issue? → Dart DevTools Memory tab
│   │   └── Look for undisposed StreamControllers, AnimationControllers
│   └── Network slow? → Dart DevTools Network tab
│       └── Check response sizes, add pagination
└── Both platforms
    ├── Startup slow? → Trace startup sequence, defer non-critical init
    ├── Image heavy? → Check cache policy, resize on server, use thumbnails
    └── List jank? → Ensure virtualization, fixed heights, pre-calculated layouts
```

## Performance Profiling

**React Native Profiling:**
```typescript
// Enable Hermes profiling
// In metro.config.js, hermes is enabled by default in RN 0.70+

// Performance monitoring hook
import { PerformanceObserver, performance } from 'perf_hooks'

function useRenderTiming(componentName: string) {
  useEffect(() => {
    const startTime = performance.now()

    return () => {
      const endTime = performance.now()
      if (__DEV__) {
        console.log(`${componentName} render time: ${endTime - startTime}ms`)
      }
    }
  })
}

// Measure component interactions
import { InteractionManager } from 'react-native'

function ExpensiveScreen() {
  const [isReady, setIsReady] = useState(false)

  useEffect(() => {
    // Wait for animations to complete before heavy work
    InteractionManager.runAfterInteractions(() => {
      setIsReady(true)
      loadExpensiveData()
    })
  }, [])

  if (!isReady) return <SkeletonLoader />
  return <ActualContent />
}
```

**Flipper Performance Plugin:**
```typescript
// Install: yarn add react-native-flipper
// Flipper plugins: React DevTools, Network, Databases, Hermes Debugger

// Custom Flipper plugin for performance
import { addPlugin } from 'react-native-flipper'

if (__DEV__) {
  addPlugin({
    getId() { return 'performance-monitor' },
    onConnect(connection) {
      // Send performance metrics to Flipper
    },
    onDisconnect() {},
  })
}
```

## List Optimization

**Optimized FlatList:**
```typescript
import { memo, useCallback, useMemo } from 'react'
import { FlatList, ViewToken } from 'react-native'

interface OptimizedListProps<T> {
  data: T[]
  renderItem: (item: T) => JSX.Element
  itemHeight: number
  onEndReached?: () => void
}

function OptimizedList<T extends { id: string }>({
  data,
  renderItem,
  itemHeight,
  onEndReached,
}: OptimizedListProps<T>) {
  // Memoize render function
  const renderItemCallback = useCallback(
    ({ item }: { item: T }) => renderItem(item),
    [renderItem]
  )

  // Stable key extractor
  const keyExtractor = useCallback((item: T) => item.id, [])

  // Pre-calculate item layout for better performance
  const getItemLayout = useCallback(
    (_: T[] | null | undefined, index: number) => ({
      length: itemHeight,
      offset: itemHeight * index,
      index,
    }),
    [itemHeight]
  )

  // Viewability config for lazy rendering
  const viewabilityConfig = useMemo(() => ({
    itemVisiblePercentThreshold: 50,
    minimumViewTime: 300,
  }), [])

  return (
    <FlatList
      data={data}
      renderItem={renderItemCallback}
      keyExtractor={keyExtractor}
      getItemLayout={getItemLayout}
      // Performance props
      initialNumToRender={10}
      maxToRenderPerBatch={5}
      updateCellsBatchingPeriod={50}
      windowSize={5}
      removeClippedSubviews
      // Pagination
      onEndReached={onEndReached}
      onEndReachedThreshold={0.5}
      // Avoid layout thrashing
      maintainVisibleContentPosition={{
        minIndexForVisible: 0,
      }}
    />
  )
}

// Memoized list item
const ListItem = memo(({ item, onPress }: { item: Item; onPress: (id: string) => void }) => (
  <Pressable onPress={() => onPress(item.id)}>
    <Text>{item.name}</Text>
  </Pressable>
), (prev, next) => prev.item.id === next.item.id)
```

## Image Optimization

**React Native Fast Image:**
```typescript
import FastImage from 'react-native-fast-image'

// Preload images
FastImage.preload([
  { uri: 'https://example.com/image1.jpg', priority: FastImage.priority.high },
  { uri: 'https://example.com/image2.jpg', priority: FastImage.priority.normal },
])

// Optimized image component
function OptimizedImage({ uri, style }) {
  return (
    <FastImage
      source={{
        uri,
        priority: FastImage.priority.normal,
        cache: FastImage.cacheControl.immutable,
      }}
      style={style}
      resizeMode={FastImage.resizeMode.cover}
    />
  )
}

// Progressive image loading
function ProgressiveImage({ thumbnailUri, fullUri, style }) {
  const [loaded, setLoaded] = useState(false)

  return (
    <View style={style}>
      <FastImage
        source={{ uri: thumbnailUri }}
        style={[StyleSheet.absoluteFill, { opacity: loaded ? 0 : 1 }]}
        blurRadius={10}
      />
      <FastImage
        source={{ uri: fullUri }}
        style={StyleSheet.absoluteFill}
        onLoad={() => setLoaded(true)}
      />
    </View>
  )
}
```

## Memory Management

**Memory Leak Prevention:**
```typescript
// Cleanup subscriptions
useEffect(() => {
  const subscription = eventEmitter.addListener('event', handler)

  return () => subscription.remove()  // Always cleanup
}, [])

// Abort fetch on unmount
useEffect(() => {
  const controller = new AbortController()

  fetch(url, { signal: controller.signal })
    .then(setData)
    .catch(e => {
      if (e.name !== 'AbortError') throw e
    })

  return () => controller.abort()
}, [url])

// Weak references for large objects
const cache = new WeakMap<object, ProcessedData>()
```

## Bundle Optimization

**Code Splitting with Repack:**
```typescript
// Lazy load heavy screens
const HeavyScreen = React.lazy(() => import('./HeavyScreen'))

function App() {
  return (
    <Suspense fallback={<LoadingScreen />}>
      <HeavyScreen />
    </Suspense>
  )
}

// Analyze bundle
// npx react-native-bundle-visualizer
```

## Flutter Performance

**Widget Optimization:**
```dart
// Use const constructors
const SizedBox(height: 16);

// RepaintBoundary for complex widgets
RepaintBoundary(
  child: ComplexAnimatedWidget(),
)

// ListView.builder for large lists
ListView.builder(
  itemCount: items.length,
  itemExtent: 72,  // Fixed height for better performance
  cacheExtent: 500,
  itemBuilder: (context, index) => ItemTile(
    key: ValueKey(items[index].id),
    item: items[index],
  ),
)
```

## Anti-Patterns

### 1. Premature Optimization

**BAD** - Optimizing without measuring first:
```typescript
// Spending hours micro-optimizing a component that renders once
const MemoizedHeader = memo(({ title }) => (
  <View>
    <Text>{title}</Text>
  </View>
), (prev, next) => prev.title === next.title)
// This component renders once on mount - memo adds overhead, not value
```

**GOOD** - Profile first, optimize the actual bottleneck:
```typescript
// Step 1: Profile with Flipper/DevTools
// Step 2: Identify that ProductList re-renders 200 items on every state change
// Step 3: Optimize the actual bottleneck
const ProductItem = memo(({ product, onPress }) => (
  <Pressable onPress={() => onPress(product.id)}>
    <FastImage source={{ uri: product.image }} style={styles.image} />
    <Text>{product.name}</Text>
  </Pressable>
))
// This memo prevents 200 unnecessary re-renders - measurable impact
```

### 2. Optimizing the Wrong Layer

**BAD** - Optimizing the render when the real problem is network:
```typescript
// Developer adds memo, useMemo, useCallback everywhere
// But the real problem is fetching 5MB of uncompressed JSON
const data = await fetch('/api/products') // Returns 5MB payload with unused fields
```

**GOOD** - Fix the root cause first:
```typescript
// Add pagination, field selection, and compression
const data = await fetch('/api/products?page=1&limit=20&fields=id,name,price', {
  headers: { 'Accept-Encoding': 'gzip' },
})
// Now the payload is 15KB instead of 5MB
```

### 3. Ignoring Android Performance

**BAD** - Only testing on iOS simulator, deploying broken Android experience:
```typescript
// Works fine on iPhone 15 Pro, but crashes on mid-range Android
// because images are loaded at full resolution (4000x3000)
<Image source={{ uri: fullResUrl }} style={{ width: 100, height: 100 }} />
```

**GOOD** - Test on mid-range Android devices, serve appropriately sized images:
```typescript
// Request thumbnail from server, test on Android mid-range device
<FastImage
  source={{ uri: `${imageUrl}?w=200&h=200&format=webp` }}
  style={{ width: 100, height: 100 }}
  resizeMode={FastImage.resizeMode.cover}
/>
```

### 4. Not Using Production Builds for Profiling

**BAD** - Making optimization decisions based on debug build performance:
```text
// Debug mode: "This screen takes 3 seconds to render!"
// Production mode: Same screen takes 200ms
// Developer wasted time optimizing something that was already fast
```

**GOOD** - Always profile in release or profile mode:
```bash
# React Native: profile build
npx react-native run-android --variant release
npx react-native run-ios --configuration Release

# Flutter: profile mode (has DevTools but near-release performance)
flutter run --profile
```

### 5. Over-Caching Without Eviction

**BAD** - Caching everything with no size limit:
```typescript
const imageCache = new Map<string, ImageData>() // Grows unbounded
function cacheImage(url: string, data: ImageData) {
  imageCache.set(url, data) // Never evicts, memory grows forever
}
```

**GOOD** - Use LRU cache with size limits:
```typescript
import LRUCache from 'lru-cache'
const imageCache = new LRUCache<string, ImageData>({
  max: 100,           // Max 100 entries
  maxSize: 50_000_000, // Max 50MB total
  sizeCalculation: (value) => value.byteLength,
  ttl: 1000 * 60 * 30, // 30 min TTL
})
```

## Escalation Paths

| Situation | Hand Off To | What to Provide |
|-----------|------------|-----------------|
| Perf issue requires native module rewrite or TurboModule | `react-native-expert` | Profiling data, bridge call frequency, native API needed |
| Perf issue requires Flutter platform channel or FFI | `flutter-expert` | DevTools timeline, isolate profiling data |
| Performance fix introduces security concern (e.g., disabling pinning) | `mobile-security-specialist` | Proposed change, threat assessment |
| Need to optimize CI build times, not runtime perf | DevOps / CI specialist | Build logs, current build config |
| Perf issue is backend response time, not client | Backend team | Network traces, API latency data |

## Tool Commands

**React Native Profiling:**
```bash
# Get full RN environment info
npx react-native info

# Bundle size analysis
npx react-native-bundle-visualizer

# Generate Hermes CPU profile
adb shell am broadcast -a com.facebook.react.ACTION_PROFILE_CPU

# Check for circular dependencies (cause slow startup)
npx madge --circular src/

# Android: dump memory info for the app process
adb shell dumpsys meminfo <package_name>

# Android: check GPU rendering profile
adb shell dumpsys gfxinfo <package_name>

# Android: check for layout pass issues
adb shell dumpsys activity top | grep -A 5 "View Hierarchy"

# iOS: Instruments profiling (Time Profiler)
xcrun xctrace record --device <device_id> --template 'Time Profiler' --launch <app_bundle_id>

# iOS: Check memory footprint
xcrun xctrace record --device <device_id> --template 'Allocations' --launch <app_bundle_id>
```

**Flutter Profiling:**
```bash
# Run in profile mode for accurate performance data
flutter run --profile

# Launch Dart DevTools
dart devtools

# Analyze app size
flutter build apk --analyze-size
flutter build ios --analyze-size

# Run with verbose system logs (Android)
flutter run -v

# Skia shader warmup trace
flutter run --profile --trace-skia

# Dump widget tree for analysis
flutter run --dump-skp-on-shader-compilation
```

**General Device Profiling:**
```bash
# Android: real-time CPU/memory monitoring
adb shell top -n 1 | grep <package_name>

# Android: battery usage stats
adb shell dumpsys batterystats --charged <package_name>

# Android: network usage
adb shell dumpsys netstats detail | grep <package_name>

# iOS: check thermal state
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.apple.thermalmonitor"'

# Both: check app binary size
ls -lh android/app/build/outputs/apk/release/app-release.apk
ls -lh build/ios/ipa/*.ipa
```

## Best Practices

- **Profile before optimizing** - don't guess, measure
- **Use production builds** for accurate performance testing
- **Test on low-end devices** to catch performance issues early
- **Implement virtualization** for all lists
- **Defer expensive operations** until after initial render

## Common Pitfalls

- Not using getItemLayout when item heights are fixed
- Creating new objects/arrays in render causing re-renders
- Not cleaning up timers, subscriptions, and fetch calls
- Over-optimizing before measuring actual bottlenecks
