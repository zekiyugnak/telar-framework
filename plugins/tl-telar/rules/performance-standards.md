# Mobile App Performance Standards

## Launch Performance

| Metric | Target | Maximum |
|--------|--------|---------|
| Cold Start | < 2s | 4s |
| Warm Start | < 1s | 2s |
| Time to Interactive | < 3s | 5s |

## Runtime Performance

### Frame Rate
- Scrolling: 60 FPS (no drops below 55)
- Animations: 60 FPS
- Navigation transitions: 60 FPS

### Memory
| Platform | Max Heap | Warning Level |
|----------|----------|---------------|
| iOS (low-end) | 150MB | 100MB |
| iOS (high-end) | 300MB | 200MB |
| Android (low-end) | 100MB | 80MB |
| Android (high-end) | 250MB | 180MB |

### Bundle Size
| Platform | Initial Bundle | With Assets |
|----------|---------------|-------------|
| iOS | < 30MB | < 100MB |
| Android (APK) | < 20MB | < 80MB |
| Android (AAB) | < 15MB | < 60MB |

## Network Performance

### API Response Handling
- Show loading state immediately
- Optimistic updates where safe
- Graceful degradation on failure
- Retry with exponential backoff

### Caching Strategy
- Cache API responses (5-15 min TTL)
- Cache images aggressively
- Preload critical data
- Background refresh

## List Performance (FlatList/ListView)

### Mandatory Optimizations
```typescript
// React Native
<FlatList
  removeClippedSubviews={true}
  maxToRenderPerBatch={10}
  windowSize={5}
  initialNumToRender={10}
  getItemLayout={...} // If fixed height
/>
```

```dart
// Flutter
ListView.builder(
  itemExtent: 80, // If fixed height
  cacheExtent: 500,
  addAutomaticKeepAlives: false,
)
```

## Image Performance

### Requirements
- Use appropriate image sizes (not oversized)
- Lazy load off-screen images
- Use cached network image libraries
- Compress images before upload
- Support WebP format

### Image Caching
- Cache to disk, not just memory
- Implement cache eviction policy
- Preload hero images

## Battery & Thermal

### Guidelines
- Minimize background processing
- Batch network requests
- Use efficient location tracking
- Reduce animation complexity on low battery
- Respect Low Power Mode

## Testing Requirements

### Performance Testing Checklist
- [ ] Profile on lowest-spec target device
- [ ] Test with slow network (3G simulation)
- [ ] Test with airplane mode → reconnect
- [ ] Memory profiling for leaks
- [ ] Battery impact measurement
- [ ] Thermal impact on extended use

### Profiling Tools
- **iOS**: Xcode Instruments (Time Profiler, Allocations)
- **Android**: Android Studio Profiler
- **Flutter**: DevTools (Performance, Memory)
- **React Native**: Flipper, React DevTools
