# Mobile Load More Pagination Design

## Context

The store listings page uses server-side pagination with traditional page controls (First/Prev/Next/Last). On desktop this works well inside the table layout. On mobile, the card-based layout is better suited to a "Load More" pattern where items accumulate as the user taps a button.

## Design

### Behavior

- **Mobile (`< lg`)**: Items accumulate in a `useState` array. A "Load More" button at the bottom fetches the next page and appends items. The button disappears when all pages are loaded.
- **Desktop (`lg+`)**: Unchanged — traditional `PaginationControls` with page navigation.
- **Filter tabs**: Shared between both. Clicking a tab resets to page 1 and replaces all items.

### State

The page component adds two pieces of state:

- `mobileItems: Item[]` — accumulated items for the mobile card list
- `mobileLoading: boolean` — loading indicator for the Load More button

### Load More Navigation

Uses Inertia's `router.get` with special options to avoid disrupting the page:

```
router.get('/store/listings', { status, page: nextPage, per_page }, {
  preserveState: true,
  preserveScroll: true,
  replace: true,
  only: ['items', 'pagination'],
})
```

- `preserveState: true` — keeps React component state (accumulated items)
- `preserveScroll: true` — doesn't scroll to top
- `replace: true` — replaces current history entry instead of pushing
- `only` — partial reload, only refreshes items and pagination props

### Detection Logic

A `useEffect` watches `items` and `pagination.page`:

- If `page === 1`: replace `mobileItems` with `items` (filter change or initial load)
- If `page > 1`: append `items` to `mobileItems` (load more)

### Not in Scope

- Infinite scroll (auto-load on scroll)
- Mobile rows-per-page selector
- Different per_page defaults for mobile vs desktop
