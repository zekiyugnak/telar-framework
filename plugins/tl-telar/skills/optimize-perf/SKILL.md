---
name: "optimize-perf"
description: "Performance optimization workflow with profiling, quick wins, and deep optimization"
source_type: "command"
source_file: "commands/optimize-perf.md"
---

# optimize-perf

Migrated from `commands/optimize-perf.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:optimize-perf`; invoke it as `$optimize-perf` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# Optimize Performance

Systematic performance optimization for mobile apps.

## Phase 1: Profiling (0-25%)

### Load Agents
```yaml
agents:
  - mobile-performance-optimizer
  - mobile-performance-testing
```

### Baseline Metrics
```markdown
| Metric | Current | Target |
|--------|---------|--------|
| Cold start | 3.2s | <2s |
| TTI | 4.5s | <3s |
| FPS (scroll) | 45 | 60 |
| Memory | 180MB | <150MB |
| Bundle size | 25MB | <20MB |
```

### Profiling Tools
```markdown
React Native:
- Flipper Performance plugin
- React DevTools Profiler
- Systrace

Flutter:
- Flutter DevTools
- Performance overlay
- Timeline
```

### Identify Bottlenecks
1. **Startup profiling**
   - JS bundle load time
   - Native initialization
   - First render

2. **Runtime profiling**
   - Scroll performance
   - Navigation transitions
   - Heavy computations

3. **Memory profiling**
   - Memory leaks
   - Large allocations
   - Retained objects

### Output
- Performance baseline
- Bottleneck list
- Priority ranking

## Phase 2: Quick Wins (25-50%)

### Load Skills
```yaml
skills:
  - render-optimization
  - list-optimization
  - image-optimization
```

### Common Quick Fixes

**Re-render Prevention**
```typescript
// Add memoization
const MemoizedComponent = memo(Component)

// Stabilize callbacks
const handlePress = useCallback(() => {}, [])

// Memoize expensive computations
const sortedData = useMemo(() => sort(data), [data])
```

**List Optimization**
```typescript
<FlatList
  removeClippedSubviews={true}
  maxToRenderPerBatch={10}
  windowSize={5}
  getItemLayout={(data, index) => ({
    length: ITEM_HEIGHT,
    offset: ITEM_HEIGHT * index,
    index,
  })}
/>
```

**Image Optimization**
```typescript
// Use FastImage with caching
<FastImage
  source={{ uri, cache: FastImage.cacheControl.immutable }}
  resizeMode={FastImage.resizeMode.cover}
/>
```

**Import Optimization**
```typescript
// ❌ Before
import _ from 'lodash'

// ✅ After
import debounce from 'lodash/debounce'
```

### Output
- Quick wins implemented
- Immediate performance gain

## Phase 3: Deep Optimization (50-85%)

### Load Skills
```yaml
skills:
  - memory-management
  - bundle-optimization
  - startup-optimization
```

### Startup Optimization
```typescript
// Defer non-critical initialization
InteractionManager.runAfterInteractions(() => {
  initializeAnalytics()
  prefetchData()
})

// Lazy load screens
const HeavyScreen = React.lazy(() => import('./HeavyScreen'))
```

### Bundle Optimization
```bash
# Analyze bundle
npx react-native-bundle-visualizer

# Enable Hermes
# android/app/build.gradle
hermesEnabled: true
```

### Memory Optimization
```typescript
// Clean up subscriptions
useEffect(() => {
  const subscription = eventEmitter.addListener(handler)
  return () => subscription.remove()
}, [])

// Clear caches on memory warning
AppState.addEventListener('memoryWarning', () => {
  FastImage.clearMemoryCache()
})
```

### Native Optimization
- Enable ProGuard/R8 for Android
- Enable bitcode for iOS
- Optimize native modules

### Output
- Deep optimizations applied
- Significant performance improvement

## Phase 4: Validation (85-100%)

### Performance Testing
```markdown
Test scenarios:
1. Cold start (kill app, launch)
2. Warm start (background, foreground)
3. Scroll through 1000 items
4. Navigate 10 screens rapidly
5. Memory after 30 min usage
```

### Metrics Comparison
```markdown
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Cold start | 3.2s | 1.8s | 44% |
| FPS (scroll) | 45 | 58 | 29% |
| Memory | 180MB | 140MB | 22% |
| Bundle | 25MB | 18MB | 28% |
```

### Regression Prevention
- Add performance tests to CI
- Set performance budgets
- Monitor in production

### Output
- Validation report
- Performance comparison
- Monitoring setup

## Completion Checklist

- [ ] Baseline metrics captured
- [ ] Bottlenecks identified
- [ ] Quick wins implemented
- [ ] Deep optimizations applied
- [ ] Performance validated
- [ ] Targets met
- [ ] Monitoring in place
