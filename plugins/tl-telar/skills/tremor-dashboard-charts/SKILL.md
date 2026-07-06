---
name: "tremor-dashboard-charts"
description: "Tremor is a React component library purpose-built for dashboards: KPI cards, line/bar/area charts, donut charts, and small trend sparklines, all styled with Tailwind and reasonably accessible out of the box. This skill c"
source_type: "skill"
source_file: "skills/tremor-dashboard-charts.md"
---

# tremor-dashboard-charts

Migrated from `skills/tremor-dashboard-charts.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Tremor for Admin Dashboard Charts and KPI Cards

Tremor is a React component library purpose-built for dashboards: KPI cards, line/bar/area charts, donut charts, and small trend sparklines, all styled with Tailwind and reasonably accessible out of the box. This skill covers when Tremor is the right default for this admin panel, how to keep its visual output consistent with the shadcn/ui token set already in use, and the data-shape conventions its chart components expect.

## Problem

Two failure modes recur when adding charts to an admin dashboard: reaching for a low-level charting library (D3, a bare Canvas/SVG implementation) for a standard KPI trend line that doesn't need that flexibility, burning days on axis/tooltip/legend plumbing that Tremor already solved; or the opposite — using Tremor for every visualization including highly custom ones it was never designed for, then fighting its API to force an unsupported shape.

```tsx
// BAD: hand-rolled SVG line chart for a completely standard "orders per
// day, last 30 days" trend — reinvents axis scaling, tooltips, and
// responsive resizing that a dashboard library already provides
function OrdersTrendChart({ data }: { data: { date: string; count: number }[] }) {
  const svgRef = useRef<SVGSVGElement>(null)
  useEffect(() => {
    // ...100+ lines of manual d3 scale/axis/path setup for a simple trend line
  }, [data])
  return <svg ref={svgRef} />
}
```

```tsx
// BAD: data shaped as an array of arrays instead of the array-of-objects
// shape Tremor's chart components expect — renders a blank chart with no
// error, which is the most common "why is nothing showing up" report
const chartData = [
  ['2024-01-01', 42],
  ['2024-01-02', 55],
]
<LineChart data={chartData} index="date" categories={['count']} /> // blank
```

## Solution

### KPI cards for headline dashboard metrics

```tsx
// src/features/dashboard/KpiCards.tsx
import { Card, Metric, Text, Flex, BadgeDelta } from '@tremor/react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

function useKpis() {
  return useQuery({
    queryKey: ['dashboard', 'kpis'],
    queryFn: async () => {
      // RPC calls a Postgres function so the aggregation runs in the
      // database, not by fetching every row and reducing client-side.
      const { data, error } = await supabase.rpc('dashboard_kpis')
      if (error) throw error
      return data as { activeOrders: number; activeOrdersDeltaPct: number; revenueToday: number }
    },
  })
}

export function KpiCards() {
  const { data } = useKpis()
  if (!data) return <KpiCardsSkeleton />

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <Card>
        <Flex alignItems="start">
          <Text>Active Orders</Text>
          <BadgeDelta deltaType={data.activeOrdersDeltaPct >= 0 ? 'increase' : 'decrease'}>
            {Math.abs(data.activeOrdersDeltaPct)}%
          </BadgeDelta>
        </Flex>
        <Metric>{data.activeOrders.toLocaleString()}</Metric>
      </Card>
      <Card>
        <Text>Revenue Today</Text>
        <Metric>{formatCurrency(data.revenueToday)}</Metric>
      </Card>
    </div>
  )
}
```

### Line chart shaped from a Supabase aggregate query

```tsx
// src/features/dashboard/OrdersTrendChart.tsx
import { Card, Title, LineChart } from '@tremor/react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

function useOrdersTrend() {
  return useQuery({
    queryKey: ['dashboard', 'orders-trend'],
    queryFn: async () => {
      const { data, error } = await supabase.rpc('orders_per_day', { days_back: 30 })
      if (error) throw error

      // Tremor's LineChart expects an array of flat objects: one key that
      // is the x-axis "index" (here, "date") plus one key per series named
      // in `categories`. Reshape the RPC result into exactly that shape
      // here, once, rather than inside the render.
      return (data as { day: string; order_count: number }[]).map((row) => ({
        date: row.day,
        Orders: row.order_count,
      }))
    },
  })
}

export function OrdersTrendChart() {
  const { data } = useOrdersTrend()

  return (
    <Card>
      <Title>Orders — Last 30 Days</Title>
      <LineChart
        className="mt-4 h-72"
        data={data ?? []}
        index="date"
        categories={['Orders']}
        // Tremor accepts a colors array keyed to the chart's design tokens;
        // pick one that maps onto the shadcn/ui primary palette (see below)
        // rather than Tremor's default blue if the app has a distinct brand hue.
        colors={['indigo']}
        valueFormatter={(value) => value.toLocaleString()}
        showAnimation
      />
    </Card>
  )
}
```

### Donut chart for a categorical breakdown

```tsx
// Tremor's DonutChart expects the same flat-object shape: one category
// label field plus one numeric value field, referenced by `category` and
// `index` (yes — for DonutChart, `index` names the LABEL field, not an
// x-axis, which is the opposite convention from LineChart/BarChart).
import { DonutChart, Legend } from '@tremor/react'

function OrderStatusBreakdown({ data }: { data: { status: string; count: number }[] }) {
  return (
    <>
      <DonutChart
        className="h-52"
        data={data}
        category="count"
        index="status"
        colors={['emerald', 'amber', 'rose', 'slate']}
      />
      <Legend
        categories={data.map((d) => d.status)}
        colors={['emerald', 'amber', 'rose', 'slate']}
      />
    </>
  )
}
```

### Aligning Tremor's palette with shadcn/ui tokens

```ts
// tailwind.config.ts
// Tremor ships its own named color scale ('blue', 'indigo', 'emerald', etc.)
// rather than reading CSS variables directly. To keep dashboard charts
// visually consistent with the rest of a shadcn/ui-themed app, pick a
// FIXED subset of Tremor's palette that matches the app's primary/accent
// hues, and use only those names across every chart — don't let each
// chart's author pick an arbitrary color ad hoc.
export const chartPalette = {
  primary: 'indigo',   // matches --primary in the shadcn theme
  positive: 'emerald',
  warning: 'amber',
  negative: 'rose',
  neutral: 'slate',
} as const
```

## Why This Works

- **Tremor's chart components handle axis scaling, tooltips, legends, and responsive resize internally**: for the standard dashboard vocabulary (trend lines, category bars, KPI deltas, donut breakdowns), this is exactly the 80% case that doesn't need a bespoke visualization — reaching for a lower-level library here trades a finished component for weeks of re-solving already-solved problems.
- **Server-side aggregation (a Postgres RPC function) keeps the client from fetching raw rows just to sum/group them**: a `dashboard_kpis()` or `orders_per_day()` function computes the aggregate in the database, in one round trip, at a size that doesn't grow with the underlying table — the client only ever receives chart-ready numbers.
- **Reshaping API data into Tremor's expected flat-object array once, in the query function, keeps the chart component itself simple**: the component only needs `index`/`category` prop names, no inline mapping logic mixed into JSX.
- **A fixed, named color mapping keeps every dashboard chart visually consistent**: Tremor's palette is a curated named set (not arbitrary hex), so constraining every chart in the app to the same handful of names (`indigo` for primary trend, `emerald`/`rose` for positive/negative, etc.) produces a dashboard that reads as one coherent system instead of each chart picking its own colors.

## Edge Cases & Pitfalls

### Common Mistakes

- **Passing an array of arrays or a nested object instead of a flat array of objects**: every Tremor chart component expects `data: Record<string, string | number>[]` — a row with the index/category key plus one key per series. Any other shape renders a blank or broken chart with no console error, which makes this the first thing to check when "the chart shows nothing."
- **Confusing `index` semantics between chart types**: for `LineChart`/`BarChart`, `index` is the x-axis field (usually a date or category). For `DonutChart`, `index` is the slice *label* field and `category` is the numeric value field — swapping these conventions between chart types is an easy copy-paste mistake.
- **Fetching raw, ungrouped rows client-side and reducing them in a `useMemo` for a KPI or trend chart**: this works at low row counts but doesn't scale, and duplicates aggregation logic that's better expressed once as a Postgres function callable from anywhere (including future non-web clients).
- **Not setting an explicit height on the chart container** (`className="h-72"` or similar): Tremor charts are responsive to their container's width but need an explicit height, or they can collapse to zero height inside a flex/grid parent that doesn't otherwise constrain it.
- **Ignoring the `valueFormatter` prop and letting raw numbers render**: an unformatted `12500000` in a revenue KPI is far less scannable than a formatted `₺12.5M` — always pass a `valueFormatter` for currency/large-number series.
- **Reaching for a fully custom chart before checking whether Tremor's existing components (including `AreaChart`, `BarList`, `CategoryBar`, `Tracker`) already cover the need**: Tremor's component set is broader than just line/bar/donut — check it before assuming a custom build is necessary.

## Verification

```bash
# Confirm the Postgres RPC function used for a dashboard query returns
# rows in the shape the chart's mapping function expects
psql -c "SELECT * FROM orders_per_day(30);"
```

- [ ] Load the dashboard with an empty dataset (new project, zero orders) — confirm charts render an empty state rather than crashing or showing a blank canvas with no explanation.
- [ ] Resize the browser window / test on a narrow viewport — confirm charts reflow within their card rather than overflowing or clipping.
- [ ] Compare chart colors against the app's shadcn/ui theme — confirm the palette mapping is used consistently, not ad hoc per chart.
- [ ] Verify a KPI card's delta badge shows the correct increase/decrease direction and color for both positive and negative changes.
- [ ] Confirm large numbers in KPIs/tooltips are formatted (currency, thousands separators) rather than raw.

## References

- [Tremor - Components](https://www.tremor.so/docs/components/area-chart)
- [Tremor - Getting Started](https://www.tremor.so/docs/getting-started/installation)
- [shadcn/ui - Theming](https://ui.shadcn.com/docs/theming)
- [Supabase - Database Functions (RPC)](https://supabase.com/docs/guides/database/functions)
