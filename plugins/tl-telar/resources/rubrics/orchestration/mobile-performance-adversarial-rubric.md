# Mobile Performance Adversarial Rubric

## Purpose

Used by the conditional Adversarial Mobile Performance Reviewer (fired only when WU `fileScope` intersects list/animation/heavy-render code OR when WU `Checkpoint: yes` is set during release prep).

## Reviewer mode

**Adversarial.** Fresh `Task()` instance.

## Evaluation criteria

### P. Performance failures

A WU FAILS perf review if any of:

- P1. New list renders ≥20 items without virtualization (`FlatList`/`SectionList` in RN; `ListView.builder`/`ListView.separated` in Flutter). Plain `ScrollView` with `.map()` over a runtime-length array → FAIL.
- P2. `FlatList`/`SectionList` introduced without `keyExtractor` (or worse: `keyExtractor={(_, i) => i.toString()}` on a list with stable IDs available).
- P3. New image rendering uses raw network URLs without caching (`react-native-fast-image` or `CachedNetworkImage` in Flutter, or explicit RN `Image` with prefetched URI).
- P4. Animation introduced uses JS-driven `Animated` (no `useNativeDriver: true`) for transform/opacity OR Flutter `setState` per-frame.
- P5. Heavy computation (>5ms, JSON.parse on large blobs, sorting >1000 items) runs on main thread without `InteractionManager.runAfterInteractions` (RN) or `compute()` isolate (Flutter).
- P6. New `useEffect` with object/array dependency where reference identity is unstable (recreated on every render). Memoize with `useMemo`/`useCallback` or move outside component.
- P7. New screen-mount triggers >3 network requests in parallel without justification (waterfall would be fine if sequential is required, but typical case: batch them or use a single endpoint).
- P8. Image asset added at >2x the rendered size without responsive `resizeMode`. iOS `@1x/@2x/@3x` or Android `drawable-?dpi` provided. Single-resolution PNG/JPG ≥500KB → FAIL.
- P9. New `useState` on a data array that gets recomputed on every render (should be `useMemo`).
- P10. New navigation push performed before async data fetch completes, causing transition jank (move fetch to destination screen's `useEffect`).

## Verdict format

JSON per the schema. Rule IDs P1-P10. Reviewer field: `"mobile-performance"`.
