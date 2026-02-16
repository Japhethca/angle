# Table Column Sort & Filter Design

## Context

The store listings table needs interactive column headers: sortable columns (Views, Watch, Bids, Highest Bid, Item) and a filterable Status column with a dropdown. Mobile keeps pill tabs for status filtering and has no sorting (card layout has no headers).

## Design

### URL Structure

```
/store/listings                                          → All, page 1, sort by newest
/store/listings?status=active&sort=bid_count&dir=desc    → Active, sorted by bids desc
/store/listings?sort=view_count&dir=asc&page=2           → All, sorted by views asc, page 2
```

Defaults: `status=all`, `page=1`, `per_page=10`, `sort=inserted_at`, `dir=desc`.

### Backend

#### Ash Action: `:my_listings`

Add two arguments:

- `sort_field` — atom, one_of: `[:inserted_at, :view_count, :bid_count, :watcher_count, :current_price]`, default `:inserted_at`
- `sort_dir` — atom, one_of: `[:asc, :desc]`, default `:desc`

Replace `prepare build(sort: [inserted_at: :desc])` with a dynamic prepare:

```elixir
prepare fn query, _context ->
  field = Ash.Query.get_argument(query, :sort_field) || :inserted_at
  dir = Ash.Query.get_argument(query, :sort_dir) || :desc
  Ash.Query.sort(query, [{field, dir}])
end
```

#### Controller

Read `sort` and `dir` from params. Validate `sort` to one of the allowed field strings, map to atoms. Validate `dir` to `"asc"` or `"desc"`. Pass as `input` to `run_typed_query`.

#### Inertia Props

Add to existing props:
- `sort` — current sort field string (e.g. `"bid_count"`)
- `dir` — current sort direction string (`"asc"` or `"desc"`)

### Frontend

#### Desktop: `ListingTable`

Column headers become interactive:

- **Sortable columns** (Item, Views, Watch, Bids, Highest Bid): Click toggles sort direction. Shows up/down arrow when active, neutral sort icon when inactive.
- **Status column**: Click opens a dropdown popover with All/Active/Ended/Draft options. Shows current filter as text or a filter icon.
- **Actions column**: No interaction.

All interactions trigger `onNavigate` with updated params, resetting page to 1.

#### Mobile

- **Status filter**: Pill tabs above cards (existing `StatusTabs`, shown only `lg:hidden`)
- **Sorting**: Not available on mobile (no column headers)

#### StatusTabs

Becomes mobile-only (`lg:hidden` wrapper in the page component). No changes to the component itself.

### Not in Scope

- Multi-column sort
- Text search
- Category filtering
- Persisting sort preference across sessions
