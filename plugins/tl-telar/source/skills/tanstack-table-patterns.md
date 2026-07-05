---
id: tanstack-table-patterns
category: skill
impact: HIGH
impactDescription: "Keeps operator tables responsive from 100 to 500k+ rows by moving sort/filter/paginate work to Postgres instead of the browser"
tags: [tanstack-table, react-table, supabase, pagination, virtualization, admin-panel, web]
capabilities:
  - Headless table setup with column definitions and a typed row model
  - Server-side sorting, filtering, and pagination against Supabase range queries
  - Row virtualization for rendering large in-memory datasets without jank
  - Row selection state and bulk-action patterns (select-all, indeterminate, cross-page)
useWhen:
  - Building any data table in the admin panel that lists database rows
  - A table's row count is large enough that client-side filtering becomes slow
  - Adding checkbox-based bulk actions (bulk delete, bulk status change, bulk export)
  - A table needs to render thousands of rows without scroll jank
---

# Server-Side Tables and Bulk Actions with TanStack Table

TanStack Table is headless — it manages column definitions, sorting/filtering/pagination *state*, and row models, but renders nothing itself. This skill covers wiring it to Supabase for server-side pagination, switching to row virtualization when a dataset must render entirely client-side, and implementing selection state for bulk operator actions correctly across pages.

## Problem

The default temptation is to fetch every row once and let TanStack Table's client-side sorting/filtering/pagination handle the rest. That works until the table backs a real production table with tens of thousands of rows — at which point the initial fetch is slow, the payload is enormous, and every keystroke in a filter box re-scans the entire in-memory array.

```tsx
// BAD: fetches the entire table unconditionally, then relies on
// getFilteredRowModel/getSortedRowModel/getPaginationRowModel to do
// everything in the browser — fine at 200 rows, unusable at 200,000
function OrdersTable() {
  const { data: allOrders } = useQuery({
    queryKey: ['orders', 'all'],
    queryFn: () => supabase.from('orders').select('*').then((r) => r.data),
  })

  const table = useReactTable({
    data: allOrders ?? [],
    columns,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(), // paginates an array already fully in memory
  })
  // ...
}
```

```tsx
// BAD: "select all" only tracks the rows currently on screen, so an operator
// who selects all, changes the filter, and clicks "delete selected" deletes
// the WRONG rows (whatever happens to be in `selectedIds` from the old page)
const [selectedIds, setSelectedIds] = useState<string[]>([])
```

## Solution

### Column definitions

```tsx
// src/features/orders/columns.tsx
import { createColumnHelper } from '@tanstack/react-table'
import type { Order } from './types'

const columnHelper = createColumnHelper<Order>()

export const columns = [
  columnHelper.display({
    id: 'select',
    header: ({ table }) => (
      <Checkbox
        checked={table.getIsAllPageRowsSelected()}
        // "indeterminate" communicates "some, not all, of this page selected"
        indeterminate={table.getIsSomePageRowsSelected() && !table.getIsAllPageRowsSelected()}
        onCheckedChange={(v) => table.toggleAllPageRowsSelected(!!v)}
      />
    ),
    cell: ({ row }) => (
      <Checkbox
        checked={row.getIsSelected()}
        onCheckedChange={(v) => row.toggleSelected(!!v)}
      />
    ),
  }),
  columnHelper.accessor('id', { header: 'Order ID' }),
  columnHelper.accessor('customerName', { header: 'Customer' }),
  columnHelper.accessor('status', {
    header: 'Status',
    cell: (info) => <StatusBadge status={info.getValue()} />,
  }),
  columnHelper.accessor('totalAmount', {
    header: 'Total',
    cell: (info) => formatCurrency(info.getValue()),
  }),
  columnHelper.accessor('createdAt', {
    header: 'Placed',
    cell: (info) => formatRelativeDate(info.getValue()),
  }),
]
```

### Server-side sorting, filtering, and pagination against Supabase

```tsx
// src/features/orders/OrdersTable.tsx
import { useState } from 'react'
import { useQuery, keepPreviousData } from '@tanstack/react-query'
import {
  useReactTable,
  getCoreRowModel,
  type PaginationState,
  type SortingState,
  type RowSelectionState,
} from '@tanstack/react-table'
import { supabase } from '@/lib/supabase'
import { columns } from './columns'

const PAGE_SIZE = 25

// TanStack Table column ids follow the JS/TS object shape (camelCase, matching
// the `Order` type used by columnHelper.accessor above), but Postgres/PostgREST
// column names are snake_case. Sending a raw column id straight to `.order()`
// sends the wrong identifier and PostgREST returns "column does not exist" —
// map every sortable column id to its real DB column explicitly.
const SORT_COLUMN_MAP: Record<string, string> = {
  customerName: 'customer_name',
  totalAmount: 'total_amount',
  createdAt: 'created_at',
  id: 'id',
  status: 'status',
}

export function OrdersTable() {
  const [pagination, setPagination] = useState<PaginationState>({ pageIndex: 0, pageSize: PAGE_SIZE })
  const [sorting, setSorting] = useState<SortingState>([{ id: 'createdAt', desc: true }])
  const [statusFilter, setStatusFilter] = useState<string | null>(null)
  const [rowSelection, setRowSelection] = useState<RowSelectionState>({})

  const { data, isPlaceholderData } = useQuery({
    queryKey: ['orders', 'page', pagination, sorting, statusFilter] as const,
    queryFn: async () => {
      const from = pagination.pageIndex * pagination.pageSize
      const to = from + pagination.pageSize - 1
      const sort = sorting[0] ?? { id: 'createdAt', desc: true }
      const sortColumn = SORT_COLUMN_MAP[sort.id] ?? sort.id

      // PostgREST supports `alias:column` in `.select()` — aliasing snake_case
      // DB columns to the camelCase keys the `Order` type/column accessors
      // expect means the response can be used as-is, with no separate mapping
      // step. `.order()` still needs the REAL column name (aliases don't
      // apply there), which is what SORT_COLUMN_MAP is for.
      let query = supabase
        .from('orders')
        .select('id, customerName:customer_name, status, totalAmount:total_amount, createdAt:created_at', { count: 'exact' })
        .order(sortColumn, { ascending: !sort.desc })
        .range(from, to)

      // Server-side filtering: applied to the Postgres query, not to an
      // in-memory array, so it's correct and fast regardless of table size.
      if (statusFilter) query = query.eq('status', statusFilter)

      const { data, error, count } = await query
      if (error) throw error
      return { rows: data, total: count ?? 0 }
    },
    placeholderData: keepPreviousData,
  })

  const table = useReactTable({
    data: data?.rows ?? [],
    columns,
    // getRowId ties selection state to a stable database id instead of the
    // row's array index, which matters once pagination/sorting change.
    getRowId: (row) => row.id,
    pageCount: data ? Math.ceil(data.total / pagination.pageSize) : -1,
    state: { pagination, sorting, rowSelection },
    onPaginationChange: setPagination,
    onSortingChange: setSorting,
    onRowSelectionChange: setRowSelection,
    manualPagination: true,
    manualSorting: true,
    manualFiltering: true,
    getCoreRowModel: getCoreRowModel(),
  })

  return (
    <>
      <BulkActionsBar selectedIds={Object.keys(rowSelection)} onClearSelection={() => setRowSelection({})} />
      <DataTable table={table} dimmed={isPlaceholderData} />
    </>
  )
}
```

### Row virtualization for a client-side table that must render fully

```tsx
// src/features/audit-log/AuditLogTable.tsx
// Use this pattern only for datasets that genuinely need to render entirely
// client-side (e.g. a locally-loaded export preview) — for normal database
// tables, prefer server-side pagination above instead of loading everything
// and virtualizing it.
import { useRef } from 'react'
import { useReactTable, getCoreRowModel } from '@tanstack/react-table'
import { useVirtualizer } from '@tanstack/react-virtual'

function AuditLogTable({ rows }: { rows: AuditLogEntry[] }) {
  const table = useReactTable({ data: rows, columns, getCoreRowModel: getCoreRowModel() })
  const tableRows = table.getRowModel().rows
  const parentRef = useRef<HTMLDivElement>(null)

  const rowVirtualizer = useVirtualizer({
    count: tableRows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 44, // px, must match the real row height closely
    overscan: 12,
  })

  return (
    <div ref={parentRef} className="h-[600px] overflow-auto">
      <div style={{ height: rowVirtualizer.getTotalSize(), position: 'relative' }}>
        {rowVirtualizer.getVirtualItems().map((virtualRow) => {
          const row = tableRows[virtualRow.index]
          return (
            <div
              key={row.id}
              style={{
                position: 'absolute',
                top: 0,
                transform: `translateY(${virtualRow.start}px)`,
                height: virtualRow.size,
                width: '100%',
              }}
            >
              <TableRow row={row} />
            </div>
          )
        })}
      </div>
    </div>
  )
}
```

### Bulk actions across pages (not just the visible page)

```tsx
// src/features/orders/BulkActionsBar.tsx
// rowSelection keys are the stable order IDs (from getRowId above), so
// selections made on page 1 survive navigating to page 2 — this is the
// difference between "select all on this page" and "select all matching rows."
function BulkActionsBar({ selectedIds, onClearSelection }: { selectedIds: string[]; onClearSelection: () => void }) {
  const bulkUpdateStatus = useMutation({
    mutationFn: async (status: string) => {
      // A single .in() call, not N sequential requests — one round trip
      // regardless of how many rows are selected. RLS still applies per row.
      const { error } = await supabase.from('orders').update({ status }).in('id', selectedIds)
      if (error) throw error
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['orders'] })
      onClearSelection()
    },
  })

  if (selectedIds.length === 0) return null

  return (
    <div className="flex items-center gap-3 p-3 bg-muted rounded-md">
      <span>{selectedIds.length} selected</span>
      <Button onClick={() => bulkUpdateStatus.mutate('shipped')}>Mark as Shipped</Button>
      <Button variant="ghost" onClick={onClearSelection}>Clear</Button>
    </div>
  )
}
```

## Why This Works

- **`manualPagination`/`manualSorting`/`manualFiltering` tell the table "the data you were given is already the correct page/order/filter"**: without these flags, TanStack Table assumes it received the *entire* dataset and re-applies its own client-side row models on top of an already-paginated server response, producing a table that appears to show only 1-2 rows per page regardless of `pageSize`.
- **`count: 'exact'` on the Supabase query returns the true total row count in the same request**: this is what lets `pageCount` be calculated correctly for "page 3 of 40" style pagination UI without a second COUNT query.
- **`getRowId` keyed to the database primary key, not the array index, makes selection state stable across pagination and sorting**: index-based selection ("row 3 is selected") silently points at a different row once the page or sort order changes; id-based selection ("order `ord_123` is selected") does not.
- **Row virtualization only renders DOM nodes for rows in (or near) the visible scroll viewport**: `useVirtualizer` tracks scroll position and computes which of the thousands of rows are actually visible, so the DOM node count stays roughly constant regardless of total row count — this is what keeps scrolling smooth at scale for client-side datasets.

## Edge Cases & Pitfalls

### Common Mistakes

- **Mixing server-side and client-side row models**: setting `manualSorting: true` but still calling `getSortedRowModel()` in the table config re-sorts the already-server-sorted page client-side, which can visually "flicker" the order or silently double-apply a sort direction.
- **Using `getIsAllRowsSelected()` (all rows across all pages) when you mean `getIsAllPageRowsSelected()` (just this page)**: with server-side pagination, `getIsAllRowsSelected()` only knows about rows currently loaded into the table instance, which is just one page — it cannot represent "every row in the database" without an explicit separate "select all matching filter" action.
- **Forgetting `overscan` in `useVirtualizer`**: with `overscan: 0`, fast scrolling shows blank flashes as rows mount just slightly too late; a modest overscan (8-16 rows) pre-renders a buffer above and below the viewport.
- **Estimating row height wildly wrong in `estimateSize`**: if actual rendered row height differs significantly from the estimate (e.g. rows contain wrapping text of variable length), the scrollbar thumb jumps and jitters as the virtualizer corrects its measurements. Keep row content height fixed, or use the virtualizer's dynamic measurement API.
- **Running a bulk action as N sequential Supabase calls in a loop** instead of one `.in('id', ids)` call — this is both slower (N round trips) and non-atomic (a failure partway through leaves some rows updated and others not).

## Verification

```bash
# Confirm the Postgres query plan uses the index backing your sort/filter
# columns rather than a sequential scan, especially on large tables
# (run inside the Supabase SQL editor or psql)
EXPLAIN ANALYZE SELECT * FROM orders ORDER BY created_at DESC LIMIT 25;
```

- [ ] Load a table with a dataset larger than one page — confirm the Network tab shows only ~25 rows transferred per page, not the full table.
- [ ] Change the sort column — confirm a new request fires with the updated `.order()` and the row order updates without a client-side re-sort artifact.
- [ ] Select rows on page 1, navigate to page 2, navigate back to page 1 — confirm the original selection is still checked.
- [ ] Scroll a virtualized table with 10,000+ rows — confirm frame rate stays smooth and the DOM node count (via devtools) stays roughly constant, not proportional to row count.
- [ ] Run a bulk action against 50+ selected rows — confirm exactly one network request fires, not one per row.

## References

- [TanStack Table - Column Defs](https://tanstack.com/table/latest/docs/guide/column-defs)
- [TanStack Table - Server-Side Pagination](https://tanstack.com/table/latest/docs/guide/pagination#manual-server-side-pagination)
- [TanStack Table - Row Selection](https://tanstack.com/table/latest/docs/guide/row-selection)
- [TanStack Virtual](https://tanstack.com/virtual/latest/docs/introduction)
- [Supabase - Pagination](https://supabase.com/docs/reference/javascript/range)
