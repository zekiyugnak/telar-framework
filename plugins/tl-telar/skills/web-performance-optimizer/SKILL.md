---
name: "web-performance-optimizer"
description: "Profiling-first specialist for web application performance — Core Web Vitals, bundle size, rendering, data fetching, and asset optimization across Vite, Next.js, and Astro stacks."
source_type: "agent"
source_file: "agents/web-performance-optimizer.md"
---

# web-performance-optimizer

Migrated from `agents/web-performance-optimizer.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Web Performance Optimizer

Profiling-first specialist for web application performance — Core Web Vitals, bundle size, rendering, data fetching, and asset optimization across Vite, Next.js, and Astro stacks.

**Golden rule: measure before optimizing. Every recommendation below is valid only after a profile or audit confirms it is the bottleneck.**

## Performance Budgets

| Metric | Target (Good) | Warning | Critical |
|--------|---------------|---------|----------|
| **LCP** (Largest Contentful Paint) | < 2.5 s | 2.5–4 s | > 4 s |
| **INP** (Interaction to Next Paint) | < 200 ms | 200–500 ms | > 500 ms |
| **CLS** (Cumulative Layout Shift) | < 0.1 | 0.1–0.25 | > 0.25 |
| **TTFB** (Time to First Byte) | < 600 ms | 600 ms–1.8 s | > 1.8 s |
| **FCP** (First Contentful Paint) | < 1.8 s | 1.8–3 s | > 3 s |
| **Total Blocking Time** | < 200 ms | 200–600 ms | > 600 ms |
| **Initial JS (gzip)** | < 200 KB | 200–400 KB | > 400 KB |
| **Route chunk (gzip)** | < 100 KB | 100–200 KB | > 200 KB |
| **Image (hero, above fold)** | < 200 KB | 200–500 KB | > 500 KB |
| **Lighthouse Performance Score** | ≥ 90 | 70–89 | < 70 |

## Profiling Workflow

```
START: What metric is failing?
├── LCP
│   ├── LCP element = image? → check CDN delivery, preload hint, width/height
│   ├── LCP element = text? → check web font load order, font-display
│   └── LCP element = block? → check render-blocking scripts/stylesheets
├── INP / Long Tasks
│   ├── Open Chrome DevTools → Performance panel → record interaction
│   ├── Find Long Task (orange bar) → identify slow JS call
│   ├── Re-render storm? → React DevTools Profiler → flame chart
│   └── CPU-bound sync work? → move to web worker
├── CLS
│   ├── WebPageTest filmstrip → find layout shift frame
│   └── Fix: reserve space (aspect-ratio), set width/height on images
├── TTFB
│   ├── Server slow? → profile SSR path, enable streaming
│   └── Not cached? → add CDN, configure Cache-Control headers
└── Bundle size
    ├── vite-bundle-visualizer or @next/bundle-analyzer
    ├── Find heavy modules → lazy import them
    └── Check for duplicate deps (npm dedupe / pnpm dedupe)
```

## Core Patterns

### Pattern 1: Route-Level Code Splitting (Vite / React Router)

```typescript
// BEFORE — entire admin module loaded on every page
import { AdminDashboard } from './admin/AdminDashboard'

// AFTER — loaded only when the /admin route is visited
import { lazy, Suspense } from 'react'
import { createBrowserRouter } from 'react-router-dom'

const AdminDashboard = lazy(() => import('./admin/AdminDashboard'))
// Heavy optional dependencies stay out of the initial chunk
const ChartPage = lazy(() =>
  import('./charts/ChartPage').then(m => ({ default: m.ChartPage }))
)

export const router = createBrowserRouter([
  {
    path: '/admin',
    element: (
      <Suspense fallback={<PageSkeleton />}>
        <AdminDashboard />
      </Suspense>
    ),
  },
])
```

### Pattern 2: Targeted React Memoization (profile first)

```typescript
// Step 1: measure in React DevTools Profiler — only memoize if
// component renders > 5× per interaction AND render time > 1 ms

// WRONG — memo on a component that renders once on mount
const PageTitle = memo(({ title }: { title: string }) => <h1>{title}</h1>)

// RIGHT — memo on a list item that re-renders 200× during parent updates
interface ProductItemProps {
  product: Product
  onAddToCart: (id: string) => void
}

const ProductItem = memo(
  ({ product, onAddToCart }: ProductItemProps) => (
    <div>
      <img src={product.imageUrl} width={200} height={200} loading="lazy" alt={product.name} />
      <p>{product.name}</p>
      <button onClick={() => onAddToCart(product.id)}>Add</button>
    </div>
  ),
  (prev, next) => prev.product.id === next.product.id && prev.product.updatedAt === next.product.updatedAt
)

// Stabilize the callback so ProductItem's memo comparison holds
function ProductList({ products }: { products: Product[] }) {
  const { mutate } = useAddToCartMutation()
  const handleAdd = useCallback((id: string) => mutate({ productId: id }), [mutate])
  return products.map(p => <ProductItem key={p.id} product={p} onAddToCart={handleAdd} />)
}
```

### Pattern 3: List Virtualization (TanStack Virtual)

```typescript
import { useVirtualizer } from '@tanstack/react-virtual'
import { useRef } from 'react'

function VirtualList({ items }: { items: Order[] }) {
  const parentRef = useRef<HTMLDivElement>(null)

  const rowVirtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 72,   // px — measure your real item height once
    overscan: 5,
  })

  return (
    <div ref={parentRef} style={{ height: '600px', overflowY: 'auto' }}>
      <div style={{ height: rowVirtualizer.getTotalSize() }}>
        {rowVirtualizer.getVirtualItems().map(virtualItem => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: virtualItem.start,
              width: '100%',
              height: virtualItem.size,
            }}
          >
            <OrderRow order={items[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  )
}
```

### Pattern 4: Parallel Fetching and TanStack Query Cache Tuning

```typescript
import { useQueries, useQuery } from '@tanstack/react-query'

// WRONG — sequential waterfall (each waits for the previous)
function ProfilePage() {
  const { data: user } = useQuery({ queryKey: ['user'], queryFn: getUser })
  const { data: orders } = useQuery({
    queryKey: ['orders', user?.id],
    queryFn: () => getOrders(user!.id),
    enabled: !!user,   // blocks on user fetch
  })
}

// RIGHT — parallel when IDs are already known; route loader pre-fetches both
export async function profileLoader({ params }: { params: { userId: string } }) {
  await Promise.all([
    queryClient.prefetchQuery({ queryKey: ['user', params.userId], queryFn: () => getUser(params.userId) }),
    queryClient.prefetchQuery({ queryKey: ['orders', params.userId], queryFn: () => getOrders(params.userId) }),
  ])
}

// Cache tuning — match staleTime to real data freshness
export const queryClientConfig = {
  defaultOptions: {
    queries: {
      staleTime: 60_000,      // 1 min: most dashboard data
      gcTime: 5 * 60_000,     // 5 min: keep in memory between nav
      refetchOnWindowFocus: false,
    },
  },
}

// Stable reference data (countries, currencies) — almost never stale
const { data: currencies } = useQuery({
  queryKey: ['currencies'],
  queryFn: getCurrencies,
  staleTime: Infinity,
})
```

### Pattern 5: Web Worker for CPU-Bound Work

```typescript
// worker.ts (comlink makes postMessage type-safe)
import { expose } from 'comlink'

const api = {
  parseCSV(raw: string): ParsedRow[] {
    // heavy synchronous work — safe here, won't block the main thread
    return rawParse(raw)
  },
}
expose(api)
export type WorkerApi = typeof api

// usage in component
import { wrap } from 'comlink'
import type { WorkerApi } from './worker'

const worker = new Worker(new URL('./worker.ts', import.meta.url), { type: 'module' })
const workerApi = wrap<WorkerApi>(worker)

async function handleFileUpload(file: File) {
  const text = await file.text()
  const rows = await workerApi.parseCSV(text)  // non-blocking
  setTableData(rows)
}
```

### Pattern 6: Responsive Images with Correct Sizing

```tsx
// WRONG — full-resolution image in a 300 px thumbnail slot
<img src="/photos/hero.jpg" style={{ width: 300 }} />

// RIGHT — CDN serves the right size; browser picks the best source
<img
  src="/cdn/photos/hero.webp?w=600"
  srcSet="/cdn/photos/hero.webp?w=300 300w, /cdn/photos/hero.webp?w=600 600w, /cdn/photos/hero.webp?w=1200 1200w"
  sizes="(max-width: 640px) 300px, (max-width: 1024px) 600px, 1200px"
  width={600}
  height={400}       // required to reserve layout space and prevent CLS
  loading="lazy"
  decoding="async"
  alt="Product hero"
/>

// LCP image must NOT be lazy — preload it instead
// In <head>:
// <link rel="preload" as="image" href="/cdn/photos/hero.webp?w=1200" fetchpriority="high" />
```

## Anti-Patterns

### 1. Optimizing Without Profiling

**BAD** — memoizing everything because "it might be slow":
```typescript
// Added memo to every component in the tree — no profiling done
// The overhead of memo's shallow comparison now costs more than the re-renders
const StaticBadge = memo(({ label }: { label: string }) => <span>{label}</span>)
```

**GOOD** — open React DevTools Profiler, record the interaction, find the actual slow path, then memoize only that.

### 2. Dynamic Import Inside a Component Body

**BAD** — re-runs the import on every render; defeats chunk caching:
```typescript
function Page() {
  const Chart = lazy(() => import('./Chart'))   // recreated each render
  return <Chart />
}
```

**GOOD** — define `lazy()` calls at module scope:
```typescript
const Chart = lazy(() => import('./Chart'))   // created once
function Page() { return <Chart /> }
```

### 3. Missing `width`/`height` on Images (CLS)

**BAD**:
```html
<img src="photo.jpg" style="width:100%" />
<!-- Browser doesn't know aspect ratio until image loads → layout shift -->
```

**GOOD**:
```html
<img src="photo.jpg" width="1200" height="800" style="width:100%;height:auto" />
<!-- Browser reserves the right space immediately -->
```

### 4. `staleTime: 0` on Stable Reference Data

**BAD** — every focus event refetches a list of countries that never changes:
```typescript
useQuery({ queryKey: ['countries'], queryFn: getCountries })
// staleTime defaults to 0 → refetches on every window focus
```

**GOOD**:
```typescript
useQuery({ queryKey: ['countries'], queryFn: getCountries, staleTime: Infinity })
```

### 5. Loading Heavy Libraries in the Critical Path

**BAD** — `react-pdf` and `recharts` included in the main bundle:
```typescript
import { PDFViewer } from 'react-pdf'
import { LineChart } from 'recharts'
```

**GOOD** — lazy-load and render only when needed:
```typescript
const PDFViewer = lazy(() => import('react-pdf').then(m => ({ default: m.PDFViewer })))
const LineChart = lazy(() => import('recharts').then(m => ({ default: m.LineChart })))
```

## Tool Commands

**Bundle Analysis:**
```bash
# Vite — generate interactive treemap
npx vite-bundle-visualizer
# or with the official Rollup plugin
ANALYZE=true vite build

# Next.js
ANALYZE=true next build   # requires @next/bundle-analyzer in next.config

# Find duplicate packages
npx npm-deduplicate       # npm
pnpm dedupe               # pnpm
```

**Lighthouse / Field Data:**
```bash
# CLI audit (headless Chrome)
npx lighthouse https://example.com --output html --output-path ./report.html

# PageSpeed Insights API (uses real CrUX field data)
curl "https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=https://example.com&strategy=mobile"

# WebPageTest scripted run
npx webpagetest test https://example.com --runs 3 --location ec2-us-east-1 --format json
```

**Performance CI Budget (Vite plugin):**
```typescript
// vite.config.ts — fail build if any chunk exceeds budget
import { defineConfig } from 'vite'

export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('node_modules')) return 'vendor'
        },
      },
    },
  },
})
// Add bundlesize or size-limit in package.json scripts:
// "size": "size-limit"
// .size-limit.json: [{ "path": "dist/assets/*.js", "limit": "200 KB" }]
```

## Escalation Paths

| Situation | Hand Off To | What to Provide |
|-----------|------------|-----------------|
| TTFB is high and needs SSR/edge caching architecture decisions | `nextjs-web-expert` | Lighthouse TTFB trace, current rendering strategy (SSR/ISR/SPA) |
| Astro content site with image pipeline or build-time optimization | `astro-web-expert` | Bundle report, failing CWV metrics, current Astro config |
| Admin panel TanStack Query patterns or table virtualization depth | `admin-panel-architect` | Current query config, dataset size, scroll jank profile |
| Performance regression traced to a Rust/WASM service layer | `rust-service-architect` | Network waterfall, server response time trace |
| CDN caching strategy, edge functions, or image transformation service | Infrastructure / DevOps | Current Cache-Control headers, CDN provider, image traffic volume |

## Best Practices

- **Measure first**: run Lighthouse and the Chrome Performance panel before writing any optimization code
- **Profile in production mode**: `vite build && vite preview`; never trust dev-server bundle sizes
- **Set LCP image `fetchpriority="high"`** and avoid `loading="lazy"` on above-fold images
- **Reserve layout space** for every async element (images, ads, skeleton → real content) to keep CLS < 0.1
- **Tune `staleTime` per query**: 0 ms for live data, 60 s for user data, `Infinity` for static reference data
- **Code-split at the route boundary first**, then at the component boundary for genuinely heavy optional UI
- **Move any synchronous task > 50 ms** off the main thread (web worker or chunked with `scheduler.yield`)

## Common Pitfalls

- Forgetting `width`/`height` attributes on `<img>` tags — causes CLS even when images load fast
- Calling `lazy()` inside a component instead of at module scope — recreates the Promise on every render
- Adding `memo` to cheap leaf components that only render once — adds overhead, not savings
- Not setting `fetchpriority="high"` on the LCP `<img>` — browser discovers it late in the waterfall
- Using `useEffect` + `fetch` for initial data instead of query prefetching in the loader — adds a request waterfall after hydration
- Measuring performance in the browser devtools with extensions enabled — extensions inflate Long Tasks and skew INP
