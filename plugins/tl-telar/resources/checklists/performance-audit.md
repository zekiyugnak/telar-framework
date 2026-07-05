# Mobile Performance Audit Checklist

Metric-based checklist for auditing mobile app performance.

## Startup Performance

### Cold Start
- [ ] Time to Interactive (TTI) < 2 seconds
- [ ] First Meaningful Paint < 1 second
- [ ] Splash screen bridges to app content (no white flash)
- [ ] No synchronous operations in app initialization
- [ ] Heavy SDK initialization deferred to post-interactive

### Warm Start
- [ ] App resumes from background in < 500ms
- [ ] State restored correctly on resume
- [ ] No unnecessary API calls on resume

### Measurement
```bash
# Android - measure cold start
adb shell am start-activity -W com.app/.MainActivity

# iOS - measure with Instruments
xcrun xctrace record --template "App Launch" --launch com.app

# React Native - console timing
performance.now() // in App.tsx
```

## Rendering Performance

### Frame Rate
- [ ] Consistent 60fps during scroll (UI thread < 16ms per frame)
- [ ] No dropped frames during animations
- [ ] No jank during navigation transitions
- [ ] JS thread frame time < 16ms (React Native)

### Lists
- [ ] Large lists use FlashList or optimized FlatList
- [ ] `getItemLayout` provided for fixed-height items
- [ ] `keyExtractor` uses stable unique IDs (not index)
- [ ] `windowSize` tuned (5-10 for most cases)
- [ ] Images in lists use cached/optimized components
- [ ] List items properly memoized

### Animations
- [ ] Animations run on native thread (not JS thread)
- [ ] `useNativeDriver: true` where possible (RN)
- [ ] No layout thrashing during animations
- [ ] Reanimated used for complex gestures

## Memory

### Thresholds
- [ ] App memory usage < 150MB during normal use
- [ ] No memory leaks (stable memory over time)
- [ ] Memory freed when navigating away from screens
- [ ] Images properly sized (not loading 4K for thumbnails)

### Common Leaks
- [ ] Event listeners cleaned up in useEffect return
- [ ] Subscriptions unsubscribed on unmount
- [ ] Timers cleared (setInterval, setTimeout)
- [ ] Large objects not retained in closures
- [ ] Navigation listeners removed

### Measurement
```bash
# Android
adb shell dumpsys meminfo com.app

# iOS - Instruments Memory Profiler
xcrun xctrace record --template "Leaks" --attach com.app

# React Native
# Use Flipper Memory plugin or React DevTools Profiler
```

## Network

### API Performance
- [ ] API responses rendered within 1 second
- [ ] Loading states shown within 100ms of request start
- [ ] Request deduplication prevents duplicate calls
- [ ] Retry with exponential backoff for failures
- [ ] Timeout configured (10s for API, 30s for uploads)

### Caching
- [ ] API responses cached appropriately (staleTime configured)
- [ ] Images cached locally (FastImage, CachedNetworkImage)
- [ ] Static data prefetched during idle time
- [ ] Cache invalidation strategy defined

### Optimization
- [ ] Only necessary fields selected in queries
- [ ] Pagination for large datasets
- [ ] Batch requests where possible
- [ ] Certificate pinning doesn't add noticeable latency

## Bundle Size

### Thresholds
- [ ] iOS app < 30MB (download size)
- [ ] Android AAB < 20MB (download size)
- [ ] No unused dependencies in bundle

### Optimization
- [ ] Tree shaking enabled
- [ ] Code splitting / lazy loading for screens
- [ ] Images in WebP format
- [ ] SVG used for icons (not PNGs)
- [ ] Unused imports removed
- [ ] Heavy libraries replaced with lighter alternatives

### Measurement
```bash
# React Native
npx react-native-bundle-visualizer

# Android
bundletool get-size-total --bundle=app.aab

# Flutter
flutter build apk --analyze-size
```

## Battery & Resources

- [ ] No unnecessary background processing
- [ ] Location updates use appropriate accuracy
- [ ] Background fetch intervals reasonable
- [ ] Wake locks released after use
- [ ] Animations paused when app is backgrounded
- [ ] WebSocket connections managed on app state changes

## Platform-Specific

### Android
- [ ] StrictMode shows no violations
- [ ] No excessive overdraw (Developer Options → Debug GPU Overdraw)
- [ ] ANR rate < 0.47% (Play Console threshold)
- [ ] Crash rate < 1.09% (Play Console threshold)

### iOS
- [ ] No main thread hangs > 250ms
- [ ] Energy impact acceptable (Instruments Energy Log)
- [ ] Disk writes optimized (no excessive I/O)
- [ ] Network usage efficient (no unnecessary requests)
