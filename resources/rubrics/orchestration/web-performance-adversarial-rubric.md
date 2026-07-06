# Web Performance Adversarial Rubric

## Purpose

Used by the conditional Adversarial Web Performance Reviewer (fired only when WU `fileScope` intersects route/page/component/data-fetching code OR when WU `Checkpoint: yes` is set during release prep).

## Reviewer mode

**Adversarial.** Fresh `Task()` instance.

## Evaluation criteria

### WP. Web performance failures

A WU FAILS perf review if any of:

- WP1. New route or page component added without code-splitting/dynamic import (`next/dynamic` or `React.lazy` + `Suspense`) where the module graph pulls in a heavy dependency (>50 KB gzipped) into the initial bundle.
- WP2. Heavy third-party library (charting, PDF, rich-text editor, date picker with full locale data) imported at the top of a page-level file without a dynamic/lazy wrapper — inspect bundle entrypoint, not just the import site.
- WP3. Component on a hot render path (list item, table cell, frequently re-rendered parent) lacks `React.memo` where props are stable and the component has non-trivial render work; or `React.memo` wraps it but prop drilling passes a new object/array literal on every render.
- WP4. New `useCallback` or `useMemo` dependency array contains an object, array, or function that is recreated inline on every render, making the memoization ineffective (e.g., `useMemo(() => …, [{ id }])` or `useCallback(fn, [array.filter(…)])`).
- WP5. List or table of runtime-length data rendered without virtualization (`react-window`, `react-virtual`, TanStack Virtual, or equivalent) where item count is unbounded or documented to exceed 50 rows.
- WP6. TanStack Query `useQuery` / `useInfiniteQuery` introduced without `staleTime` (defaults to 0 causing refetch on every mount) on a query that hits a non-trivial API endpoint; or `refetchOnWindowFocus: true` (default) left on an expensive or rate-limited query without explicit justification.
- WP7. New query or loader triggers N+1 fetches: component maps over a list and fires a separate `fetch`/`useQuery` per item instead of a batched request or single parameterised endpoint.
- WP8. Page or component performs a sequential request waterfall (fetch B depends on fetch A's response, fetch C depends on B) where A and B/C are independent and could run in parallel with `Promise.all` / `useQueries`.
- WP9. `<img>` element added without explicit `width`/`height` attributes (or CSS aspect-ratio equivalent) causing layout shift (CLS); or image src is a large unoptimized asset (>200 KB) without `loading="lazy"` on a below-the-fold image, or without `next/image` / `<Image>` in a Next.js context.
- WP10. Synchronous CPU-bound computation (large sort, JSON.parse on a blob >100 KB, cryptographic hash, recursive tree traversal) executed directly in a render function or event handler on the main thread without deferral to a Web Worker, `scheduler.postTask`, or `setTimeout(fn, 0)` for non-blocking split.

## Verdict format

JSON per the schema. Rule IDs WP1-WP10. Reviewer field: `"web-perf"`.
