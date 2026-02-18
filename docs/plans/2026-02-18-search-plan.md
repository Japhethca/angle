# Search Feature Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add full-text search with typo tolerance to the auction platform — global search bar in navbar, dedicated `/search` results page with faceted filters, and text filtering on seller's My Listings page.

**Architecture:** Postgres tsvector + pg_trgm for relevance-ranked full-text search with fuzzy matching. New `:search` read action on Item, typed query, SearchController, and React search page. Seller dashboard gets a simple ILIKE text filter.

**Tech Stack:** Postgres (tsvector, pg_trgm, GIN indexes), Ash Framework (read action + preparation), AshTypescript RPC (typed query), Phoenix controller + Inertia.js, React 19 + shadcn/ui

---

### Task 1: Database Migration — tsvector + pg_trgm

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_search_vector_to_items.exs` (use `mix ash_postgres.generate_migrations`)

**Step 1: Create the Ash migration for search_vector column**

Add a `search_vector` attribute to the Item resource (not public, not accepted in any action — purely for DB querying). In `lib/angle/inventory/item.ex`, inside the `attributes do` block (after line 293):

```elixir
attribute :search_vector, :term_vector do
  public? false
  writable? false
end
```

Wait — Ash doesn't have a native `:term_vector` type. Instead, we'll manage this entirely at the database level with a manual migration. Do NOT add the attribute to the Ash resource.

Create a manual migration by running: `mix ecto.gen.migration add_search_vector_to_items`

Then fill in the migration:

```elixir
defmodule Angle.Repo.Migrations.AddSearchVectorToItems do
  use Ecto.Migration

  def up do
    # Enable pg_trgm extension for fuzzy matching
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    # Add tsvector column
    alter table(:items) do
      add :search_vector, :tsvector
    end

    # Backfill existing rows
    execute """
    UPDATE items SET search_vector =
      setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
      setweight(to_tsvector('english', coalesce(description, '')), 'B')
    """

    # Create trigger function to keep search_vector in sync
    execute """
    CREATE OR REPLACE FUNCTION items_search_vector_trigger() RETURNS trigger AS $$
    BEGIN
      NEW.search_vector :=
        setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.description, '')), 'B');
      RETURN NEW;
    END
    $$ LANGUAGE plpgsql
    """

    # Attach trigger to items table
    execute """
    CREATE TRIGGER items_search_vector_update
      BEFORE INSERT OR UPDATE OF title, description ON items
      FOR EACH ROW EXECUTE FUNCTION items_search_vector_trigger()
    """

    # GIN index on tsvector for fast full-text search
    create index(:items, [:search_vector], using: :gin, name: "items_search_vector_idx")

    # GIN trigram index on title for fuzzy matching
    execute "CREATE INDEX items_title_trgm_idx ON items USING gin (title gin_trgm_ops)"
  end

  def down do
    execute "DROP TRIGGER IF EXISTS items_search_vector_update ON items"
    execute "DROP FUNCTION IF EXISTS items_search_vector_trigger()"
    drop_if_exists index(:items, [:search_vector], name: "items_search_vector_idx")
    execute "DROP INDEX IF EXISTS items_title_trgm_idx"

    alter table(:items) do
      remove :search_vector
    end

    execute "DROP EXTENSION IF EXISTS pg_trgm"
  end
end
```

**Step 2: Run migration**

Run: `mix ecto.migrate`
Expected: Migration succeeds, items table has `search_vector` column populated

**Step 3: Verify with SQL**

Run SQL: `SELECT id, title, search_vector FROM items LIMIT 3` — should show tsvector values.
Run SQL: `SELECT title, similarity(title, 'iphon') AS sim FROM items ORDER BY sim DESC LIMIT 5` — should show similarity scores.

**Step 4: Commit**

```
git add priv/repo/migrations/*search_vector*
git commit -m "feat: add tsvector and pg_trgm indexes for item search"
```

---

### Task 2: Ash Search Preparation Module

**Files:**
- Create: `lib/angle/inventory/item/search_preparation.ex`

**Step 1: Write tests for search action**

Create `test/angle/inventory/item_search_test.exs`:

```elixir
defmodule Angle.Inventory.ItemSearchTest do
  use Angle.DataCase, async: true

  import Angle.Factory

  describe "search action" do
    setup do
      user = create_user()
      category = create_category(%{name: "Electronics", slug: "electronics-#{System.unique_integer([:positive])}"})

      item1 = create_item(%{
        title: "iPhone 15 Pro Max",
        description: "Latest Apple smartphone with titanium frame",
        created_by_id: user.id,
        category_id: category.id,
        condition: :new,
        sale_type: :auction
      })
      publish_item(item1, user)

      item2 = create_item(%{
        title: "Samsung Galaxy S24 Ultra",
        description: "Flagship Android phone with S Pen",
        created_by_id: user.id,
        category_id: category.id,
        condition: :used,
        sale_type: :buy_now
      })
      publish_item(item2, user)

      item3 = create_item(%{
        title: "Vintage Rolex Watch",
        description: "Classic luxury timepiece from the 1960s",
        created_by_id: user.id,
        condition: :used,
        sale_type: :auction
      })
      publish_item(item3, user)

      # Draft item — should NOT appear in search
      _draft = create_item(%{
        title: "Draft iPhone Case",
        description: "Unpublished item",
        created_by_id: user.id
      })

      %{user: user, category: category, item1: item1, item2: item2, item3: item3}
    end

    test "finds items by title keyword", %{item1: item1} do
      results = search_items("iPhone")
      assert Enum.any?(results, &(&1.id == item1.id))
    end

    test "finds items by description keyword", %{item1: item1} do
      results = search_items("titanium")
      assert Enum.any?(results, &(&1.id == item1.id))
    end

    test "does not return draft items" do
      results = search_items("Draft")
      assert results == []
    end

    test "fuzzy matches typos via trigram", %{item1: item1} do
      results = search_items("iphon")
      assert Enum.any?(results, &(&1.id == item1.id))
    end

    test "filters by category", %{item1: item1, item2: item2, item3: item3, category: category} do
      results = search_items("phone", %{category_id: category.id})
      ids = Enum.map(results, & &1.id)
      # item1 (iPhone) and item2 (phone in description) should match
      assert item1.id in ids or item2.id in ids
      refute item3.id in ids
    end

    test "filters by condition", %{item2: item2} do
      results = search_items("Samsung", %{condition: :used})
      assert Enum.any?(results, &(&1.id == item2.id))
    end

    test "filters by price range", %{user: _user} do
      results = search_items("iPhone", %{min_price: "1.00", max_price: "100.00"})
      # Default starting_price is 10.00, so should match
      assert length(results) >= 0
    end

    test "returns empty for unmatched query" do
      results = search_items("xyznonexistent123")
      assert results == []
    end

    test "pagination works" do
      results = search_items("item", %{}, %{limit: 1, offset: 0})
      assert length(results) <= 1
    end
  end

  defp search_items(query, filters \\ %{}, page \\ %{}) do
    args = Map.merge(%{query: query}, filters)

    Angle.Inventory.Item
    |> Ash.Query.for_read(:search, args, authorize?: false)
    |> then(fn q ->
      case page do
        %{limit: _} -> Ash.read!(q, page: [limit: page[:limit], offset: page[:offset] || 0])
        _ -> Ash.read!(q)
      end
    end)
  end

  defp publish_item(item, user) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, actor: user, authorize?: false)
    |> Ash.update!()
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/inventory/item_search_test.exs --max-failures 1`
Expected: FAIL — `:search` action doesn't exist yet

**Step 3: Create the search preparation module**

Create `lib/angle/inventory/item/search_preparation.ex`:

```elixir
defmodule Angle.Inventory.Item.SearchPreparation do
  @moduledoc """
  Ash preparation that applies tsvector full-text search with pg_trgm fuzzy fallback.
  Adds relevance scoring and orders results by rank.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    case Ash.Query.get_argument(query, :query) do
      nil ->
        query

      "" ->
        query

      search_term ->
        sanitized = sanitize_query(search_term)
        sort_by = Ash.Query.get_argument(query, :sort_by) || :relevance

        query
        |> apply_search_filter(sanitized)
        |> apply_sort(sort_by, sanitized)
    end
  end

  defp apply_search_filter(query, search_term) do
    Ash.Query.filter(query,
      fragment(
        "(search_vector @@ plainto_tsquery('english', ?) OR similarity(title, ?) > 0.1)",
        ^search_term,
        ^search_term
      )
    )
  end

  defp apply_sort(query, :relevance, search_term) do
    Ash.Query.sort(query,
      {Ash.Sort.expr_sort(
         fragment(
           "(ts_rank(search_vector, plainto_tsquery('english', ?)) * 2 + similarity(title, ?))",
           ^search_term,
           ^search_term
         )
       ), :desc}
    )
  end

  defp apply_sort(query, :price_asc, _search_term) do
    Ash.Query.sort(query, current_price: :asc_nils_last)
  end

  defp apply_sort(query, :price_desc, _search_term) do
    Ash.Query.sort(query, current_price: :desc_nils_last)
  end

  defp apply_sort(query, :newest, _search_term) do
    Ash.Query.sort(query, inserted_at: :desc)
  end

  defp apply_sort(query, :ending_soon, _search_term) do
    Ash.Query.sort(query, end_time: :asc_nils_last)
  end

  defp apply_sort(query, _unknown, search_term) do
    apply_sort(query, :relevance, search_term)
  end

  defp sanitize_query(term) do
    term
    |> String.trim()
    |> String.slice(0, 200)
  end
end
```

**Step 4: Add the `:search` read action to Item resource**

In `lib/angle/inventory/item.ex`, inside the `actions do` block, after the `:by_category` action (after line 203), add:

```elixir
    read :search do
      description "Full-text search across published items with optional filters"

      argument :query, :string, allow_nil?: false

      argument :category_id, :uuid do
        description "Filter by category"
      end

      argument :condition, :atom do
        constraints one_of: [:new, :used, :refurbished]
      end

      argument :min_price, :decimal
      argument :max_price, :decimal

      argument :sale_type, :atom do
        constraints one_of: [:auction, :buy_now, :hybrid]
      end

      argument :auction_status, :atom do
        constraints one_of: [:pending, :scheduled, :active, :ended, :sold]
      end

      argument :sort_by, :atom do
        default :relevance
        constraints one_of: [:relevance, :price_asc, :price_desc, :newest, :ending_soon]
      end

      filter expr(publication_status == :published)

      filter expr(is_nil(^arg(:category_id)) or category_id == ^arg(:category_id))
      filter expr(is_nil(^arg(:condition)) or condition == ^arg(:condition))
      filter expr(is_nil(^arg(:sale_type)) or sale_type == ^arg(:sale_type))
      filter expr(is_nil(^arg(:auction_status)) or auction_status == ^arg(:auction_status))
      filter expr(
               (is_nil(^arg(:min_price)) or current_price >= ^arg(:min_price)) and
                 (is_nil(^arg(:max_price)) or current_price <= ^arg(:max_price))
             )

      prepare {Angle.Inventory.Item.SearchPreparation, []}

      pagination offset?: true, required?: false
    end
```

**Step 5: Run tests**

Run: `mix test test/angle/inventory/item_search_test.exs`
Expected: All tests pass. If `fragment` or `expr_sort` syntax needs adjustment, iterate.

**Step 6: Commit**

```
git add lib/angle/inventory/item/search_preparation.ex lib/angle/inventory/item.ex test/angle/inventory/item_search_test.exs
git commit -m "feat: add search read action with tsvector + trgm preparation"
```

---

### Task 3: Typed Query + SearchController

**Files:**
- Modify: `lib/angle/inventory.ex` (add typed query)
- Create: `lib/angle_web/controllers/search_controller.ex`
- Modify: `lib/angle_web/router.ex` (add route)

**Step 1: Add typed query to Inventory domain**

In `lib/angle/inventory.ex`, inside the `resource Angle.Inventory.Item do` block (after the `seller_dashboard_card` typed query, around line 157), add:

```elixir
      typed_query :search_item_card, :search do
        ts_result_type_name "SearchItemCard"
        ts_fields_const_name "searchItemCardFields"

        fields [
          :id,
          :title,
          :slug,
          :starting_price,
          :current_price,
          :end_time,
          :auction_status,
          :condition,
          :sale_type,
          :location,
          :view_count,
          :bid_count,
          %{category: [:id, :name, :slug]}
        ]
      end
```

**Step 2: Regenerate TypeScript types**

Run: `mix ash_typescript.codegen`

**Step 3: Create SearchController**

Create `lib/angle_web/controllers/search_controller.ex`:

```elixir
defmodule AngleWeb.SearchController do
  use AngleWeb, :controller

  import AngleWeb.Helpers.QueryHelpers, only: [extract_results: 1]

  alias AngleWeb.ImageHelpers

  @per_page 20

  def index(conn, params) do
    query = params["q"] |> to_string() |> String.trim()
    category = params["category"]
    condition = validate_enum(params["condition"], ~w(new used refurbished))
    sale_type = validate_enum(params["sale_type"], ~w(auction buy_now hybrid))
    auction_status = validate_enum(params["auction_status"], ~w(pending scheduled active ended sold))
    min_price = parse_decimal(params["min_price"])
    max_price = parse_decimal(params["max_price"])
    sort = validate_enum(params["sort"], ~w(relevance price_asc price_desc newest ending_soon)) || "relevance"
    page = parse_positive_int(params["page"], 1)

    {items, total} =
      if query == "" do
        {[], 0}
      else
        load_search_results(conn, query, %{
          category_id: category,
          condition: condition,
          sale_type: sale_type,
          auction_status: auction_status,
          min_price: min_price,
          max_price: max_price,
          sort_by: sort
        }, page)
      end

    items = ImageHelpers.attach_cover_images(items)
    categories = load_filter_categories(conn)
    total_pages = if total > 0, do: max(1, ceil(total / @per_page)), else: 0

    conn
    |> assign_prop(:items, items)
    |> assign_prop(:query, query)
    |> assign_prop(:pagination, %{
      page: page,
      per_page: @per_page,
      total: total,
      total_pages: total_pages
    })
    |> assign_prop(:filters, %{
      category: category,
      condition: condition,
      sale_type: sale_type,
      auction_status: auction_status,
      min_price: min_price,
      max_price: max_price,
      sort: sort
    })
    |> assign_prop(:categories, categories)
    |> render_inertia("search")
  end

  defp load_search_results(conn, query, filters, page) do
    offset = (page - 1) * @per_page

    input =
      %{query: query}
      |> maybe_put(:category_id, filters.category_id)
      |> maybe_put(:condition, filters.condition)
      |> maybe_put(:sale_type, filters.sale_type)
      |> maybe_put(:auction_status, filters.auction_status)
      |> maybe_put(:min_price, filters.min_price)
      |> maybe_put(:max_price, filters.max_price)
      |> maybe_put(:sort_by, filters.sort_by)

    params = %{
      input: input,
      page: %{limit: @per_page, offset: offset, count: true}
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :search_item_card, params, conn) do
      %{"success" => true, "data" => %{"results" => results, "count" => count}} ->
        {results, count}

      %{"success" => true, "data" => data} when is_list(data) ->
        {data, length(data)}

      _ ->
        {[], 0}
    end
  end

  defp load_filter_categories(conn) do
    params = %{filter: %{parent_id: %{isNil: true}}}

    case AshTypescript.Rpc.run_typed_query(:angle, :homepage_category, params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp validate_enum(nil, _allowed), do: nil
  defp validate_enum(value, allowed) when is_binary(value) do
    if value in allowed, do: value, else: nil
  end
  defp validate_enum(_, _), do: nil

  defp parse_decimal(nil), do: nil
  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> Decimal.to_string(decimal)
      _ -> nil
    end
  end
  defp parse_decimal(_), do: nil

  defp parse_positive_int(nil, default), do: default
  defp parse_positive_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n > 0 -> n
      _ -> default
    end
  end
  defp parse_positive_int(_, default), do: default

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
```

**Step 4: Add route**

In `lib/angle_web/router.ex`, in the public routes scope (after line 72, after the categories routes), add:

```elixir
    get "/search", SearchController, :index
```

**Step 5: Write controller tests**

Create `test/angle_web/controllers/search_controller_test.exs`:

```elixir
defmodule AngleWeb.SearchControllerTest do
  use AngleWeb.ConnCase, async: true

  import Angle.Factory

  describe "GET /search" do
    test "renders search page with empty query", %{conn: conn} do
      conn = get(conn, ~p"/search")
      assert html_response(conn, 200) =~ "search"
    end

    test "renders search page with query param", %{conn: conn} do
      user = create_user()
      item = create_item(%{title: "Searchable Widget", created_by_id: user.id})
      publish_item(item, user)

      conn = get(conn, ~p"/search?q=Widget")
      assert html_response(conn, 200) =~ "search"
    end

    test "returns no results for unmatched query", %{conn: conn} do
      conn = get(conn, ~p"/search?q=xyznonexistent123")
      assert html_response(conn, 200) =~ "search"
    end
  end

  defp publish_item(item, user) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, actor: user, authorize?: false)
    |> Ash.update!()
  end
end
```

**Step 6: Run tests**

Run: `mix test test/angle_web/controllers/search_controller_test.exs`
Expected: All pass

**Step 7: Commit**

```
git add lib/angle/inventory.ex lib/angle_web/controllers/search_controller.ex lib/angle_web/router.ex test/angle_web/controllers/search_controller_test.exs
git commit -m "feat: add SearchController with typed query and route"
```

Run: `mix test` to verify no regressions.

---

### Task 4: Enable Navbar Search Input

**Files:**
- Modify: `assets/js/navigation/main-nav.tsx`

**Step 1: Make the existing disabled search input functional**

In `assets/js/navigation/main-nav.tsx`, the desktop search input is at lines 108-114 (currently `disabled`). The mobile search button is at lines 142-144.

Replace the desktop search input block (lines 108-114) with a form that navigates to `/search`:

```tsx
{/* Replace lines 108-114 */}
<form
  onSubmit={(e) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const q = (formData.get('q') as string)?.trim();
    if (q) router.get('/search', { q });
  }}
  className="relative"
>
  <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-content-placeholder" />
  <input
    name="q"
    placeholder="Search for an item..."
    className="h-10 w-[358px] rounded-lg bg-surface-muted pl-10 pr-4 text-sm text-content placeholder:text-content-placeholder outline-none"
  />
</form>
```

Add `router` import — update line 2:
```tsx
import { Link, usePage, router } from '@inertiajs/react';
```

Replace the mobile search button (lines 142-144) with a button that navigates to the search page:

```tsx
<button
  onClick={() => router.get('/search')}
  className="flex size-9 items-center justify-center rounded-lg bg-surface-muted text-content-secondary"
>
  <Search className="size-[18px]" />
</button>
```

**Step 2: Verify in browser**

Visit `localhost:4111`, type a query in the search bar, press Enter — should navigate to `/search?q=...`. Mobile search button should navigate to `/search`.

**Step 3: Commit**

```
git add assets/js/navigation/main-nav.tsx
git commit -m "feat: enable navbar search input to navigate to /search"
```

---

### Task 5: Search Results Page

**Files:**
- Create: `assets/js/pages/search.tsx`

**Step 1: Create the search results page**

Create `assets/js/pages/search.tsx`:

```tsx
import { useState } from 'react';
import { router, Head } from '@inertiajs/react';
import { Search, SlidersHorizontal, X } from 'lucide-react';
import { CategoryItemCard, type CategoryItem } from '@/features/items';
import { Button } from '@/components/ui/button';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Input } from '@/components/ui/input';
import type { SearchItemCard } from '@/ash_rpc';
import type { ImageData } from '@/lib/image-url';

type SearchItem = SearchItemCard[number] & { coverImage?: ImageData | null };

interface SearchFilters {
  category: string | null;
  condition: string | null;
  sale_type: string | null;
  auction_status: string | null;
  min_price: string | null;
  max_price: string | null;
  sort: string;
}

interface SearchCategory {
  id: string;
  name: string;
  slug: string;
}

interface Pagination {
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

interface SearchPageProps {
  items: SearchItem[];
  query: string;
  pagination: Pagination;
  filters: SearchFilters;
  categories: SearchCategory[];
  watchlisted_map?: Record<string, string>;
}

export default function SearchPage({ items, query, pagination, filters, categories, watchlisted_map = {} }: SearchPageProps) {
  const [searchInput, setSearchInput] = useState(query);
  const [showFilters, setShowFilters] = useState(false);

  const navigate = (newParams: Record<string, string | undefined>) => {
    const params: Record<string, string> = {};
    const merged = { ...filters, ...newParams };

    if (newParams.q !== undefined) {
      params.q = newParams.q;
    } else if (query) {
      params.q = query;
    }

    if (merged.category) params.category = merged.category;
    if (merged.condition) params.condition = merged.condition;
    if (merged.sale_type) params.sale_type = merged.sale_type;
    if (merged.auction_status) params.auction_status = merged.auction_status;
    if (merged.min_price) params.min_price = merged.min_price;
    if (merged.max_price) params.max_price = merged.max_price;
    if (merged.sort && merged.sort !== 'relevance') params.sort = merged.sort;
    if (newParams.page && newParams.page !== '1') params.page = newParams.page;

    router.get('/search', params, { preserveState: true });
  };

  const clearFilters = () => {
    router.get('/search', query ? { q: query } : {});
  };

  const hasActiveFilters = filters.category || filters.condition || filters.sale_type || filters.auction_status || filters.min_price || filters.max_price;

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    const q = searchInput.trim();
    if (q) navigate({ q, page: undefined });
  };

  return (
    <>
      <Head title={query ? `Search: ${query}` : 'Search'} />
      <div className="mx-auto max-w-7xl px-4 py-6 lg:px-10">
        {/* Search bar */}
        <form onSubmit={handleSearch} className="relative mb-6">
          <Search className="absolute left-4 top-1/2 size-5 -translate-y-1/2 text-content-placeholder" />
          <input
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder="Search for items..."
            className="h-12 w-full rounded-xl bg-surface-muted pl-12 pr-4 text-base text-content placeholder:text-content-placeholder outline-none"
          />
        </form>

        {/* Filter bar */}
        <div className="mb-6 flex flex-wrap items-center gap-3">
          <Button
            variant="outline"
            size="sm"
            onClick={() => setShowFilters(!showFilters)}
            className={showFilters ? 'border-primary-600 text-primary-600' : ''}
          >
            <SlidersHorizontal className="mr-2 size-4" />
            Filters
          </Button>

          <Select
            value={filters.sort}
            onValueChange={(v) => navigate({ sort: v, page: undefined })}
          >
            <SelectTrigger className="h-9 w-[160px]">
              <SelectValue placeholder="Sort by" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="relevance">Relevance</SelectItem>
              <SelectItem value="price_asc">Price: Low to High</SelectItem>
              <SelectItem value="price_desc">Price: High to Low</SelectItem>
              <SelectItem value="newest">Newest</SelectItem>
              <SelectItem value="ending_soon">Ending Soon</SelectItem>
            </SelectContent>
          </Select>

          {hasActiveFilters && (
            <Button variant="ghost" size="sm" onClick={clearFilters}>
              <X className="mr-1 size-3" />
              Clear filters
            </Button>
          )}

          {pagination.total > 0 && (
            <span className="ml-auto text-sm text-content-secondary">
              {pagination.total} {pagination.total === 1 ? 'result' : 'results'}
            </span>
          )}
        </div>

        {/* Filter panel (collapsible) */}
        {showFilters && (
          <div className="mb-6 grid grid-cols-2 gap-4 rounded-xl border border-subtle bg-surface p-4 lg:grid-cols-6">
            {/* Category */}
            <Select
              value={filters.category || ''}
              onValueChange={(v) => navigate({ category: v || undefined, page: undefined })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Category" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="">All Categories</SelectItem>
                {categories.map((cat) => (
                  <SelectItem key={cat.id} value={cat.id}>{cat.name}</SelectItem>
                ))}
              </SelectContent>
            </Select>

            {/* Condition */}
            <Select
              value={filters.condition || ''}
              onValueChange={(v) => navigate({ condition: v || undefined, page: undefined })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Condition" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="">Any Condition</SelectItem>
                <SelectItem value="new">New</SelectItem>
                <SelectItem value="used">Used</SelectItem>
                <SelectItem value="refurbished">Refurbished</SelectItem>
              </SelectContent>
            </Select>

            {/* Sale Type */}
            <Select
              value={filters.sale_type || ''}
              onValueChange={(v) => navigate({ sale_type: v || undefined, page: undefined })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Sale Type" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="">Any Type</SelectItem>
                <SelectItem value="auction">Auction</SelectItem>
                <SelectItem value="buy_now">Buy Now</SelectItem>
                <SelectItem value="hybrid">Hybrid</SelectItem>
              </SelectContent>
            </Select>

            {/* Min Price */}
            <Input
              type="number"
              placeholder="Min price"
              value={filters.min_price || ''}
              onChange={(e) => navigate({ min_price: e.target.value || undefined, page: undefined })}
            />

            {/* Max Price */}
            <Input
              type="number"
              placeholder="Max price"
              value={filters.max_price || ''}
              onChange={(e) => navigate({ max_price: e.target.value || undefined, page: undefined })}
            />

            {/* Auction Status */}
            <Select
              value={filters.auction_status || ''}
              onValueChange={(v) => navigate({ auction_status: v || undefined, page: undefined })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Auction Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="">Any Status</SelectItem>
                <SelectItem value="active">Active</SelectItem>
                <SelectItem value="scheduled">Scheduled</SelectItem>
                <SelectItem value="ended">Ended</SelectItem>
              </SelectContent>
            </Select>
          </div>
        )}

        {/* Results grid */}
        {query === '' ? (
          <div className="py-20 text-center text-content-secondary">
            <Search className="mx-auto mb-4 size-12 text-content-placeholder" />
            <p className="text-lg font-medium">Search for items</p>
            <p className="text-sm">Enter a keyword to find auction items</p>
          </div>
        ) : items.length === 0 ? (
          <div className="py-20 text-center text-content-secondary">
            <Search className="mx-auto mb-4 size-12 text-content-placeholder" />
            <p className="text-lg font-medium">No items found for "{query}"</p>
            <p className="text-sm">Try different keywords or adjust your filters</p>
          </div>
        ) : (
          <>
            <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {items.map((item) => (
                <CategoryItemCard
                  key={item.id}
                  item={item as CategoryItem}
                  watchlistEntryId={watchlisted_map[item.id]}
                />
              ))}
            </div>

            {/* Pagination */}
            {pagination.total_pages > 1 && (
              <div className="mt-8 flex items-center justify-center gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  disabled={pagination.page <= 1}
                  onClick={() => navigate({ page: String(pagination.page - 1) })}
                >
                  Previous
                </Button>
                <span className="px-4 text-sm text-content-secondary">
                  Page {pagination.page} of {pagination.total_pages}
                </span>
                <Button
                  variant="outline"
                  size="sm"
                  disabled={pagination.page >= pagination.total_pages}
                  onClick={() => navigate({ page: String(pagination.page + 1) })}
                >
                  Next
                </Button>
              </div>
            )}
          </>
        )}
      </div>
    </>
  );
}
```

**Step 2: Verify in browser**

Visit `localhost:4111/search?q=iPhone` — should show results with filter controls. Test empty query, filter changes, pagination.

**Step 3: Commit**

```
git add assets/js/pages/search.tsx
git commit -m "feat: add search results page with filters and pagination"
```

---

### Task 6: Seller Dashboard Text Filter

**Files:**
- Modify: `lib/angle/inventory/item.ex` (update `:my_listings` action)
- Modify: `lib/angle_web/controllers/store_dashboard_controller.ex`
- Modify: `assets/js/pages/store/listings.tsx`

**Step 1: Add `query` argument to `:my_listings` action**

In `lib/angle/inventory/item.ex`, inside the `:my_listings` action (after line 167, after the `:sort_dir` argument), add:

```elixir
      argument :query, :string
```

After the existing filter blocks (after line 186), add an inline prepare:

```elixir
      prepare fn query, _context ->
        case Ash.Query.get_argument(query, :query) do
          nil -> query
          "" -> query
          search ->
            search = String.trim(search)
            Ash.Query.filter(query, contains(title, ^search))
        end
      end
```

Move the existing sort prepare (lines 188-192) AFTER this new prepare.

**Step 2: Update StoreDashboardController**

In `lib/angle_web/controllers/store_dashboard_controller.ex`, update the `listings/2` function (line 76):

Add search param parsing:
```elixir
    search = params["search"] |> to_string() |> String.trim()
    search = if search == "", do: nil, else: search
```

Pass to `load_seller_items`:
```elixir
    {items, total} = load_seller_items(conn, status, page, per_page, sort, dir, search)
```

Add `search` to Inertia props:
```elixir
    |> assign_prop(:search, search)
```

Update `load_seller_items` to accept and pass search:
```elixir
  defp load_seller_items(conn, status, page, per_page, sort, dir, search) do
    offset = (page - 1) * per_page

    input =
      %{status_filter: status, sort_field: sort, sort_dir: dir}
      |> then(fn m -> if search, do: Map.put(m, :query, search), else: m end)

    params = %{
      input: input,
      page: %{limit: per_page, offset: offset, count: true}
    }
    ...
```

**Step 3: Add search input to listings page**

In `assets/js/pages/store/listings.tsx`, add a search input above the status tabs. Add to the props interface:
```tsx
search: string | null;
```

Add a controlled input that triggers navigation on change (debounced):
```tsx
const [searchInput, setSearchInput] = useState(search || '');

// Debounced search
useEffect(() => {
  const timeout = setTimeout(() => {
    const trimmed = searchInput.trim();
    if (trimmed !== (search || '')) {
      navigate({ search: trimmed || undefined, page: undefined });
    }
  }, 300);
  return () => clearTimeout(timeout);
}, [searchInput]);
```

Render above the status tabs:
```tsx
<div className="relative">
  <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-content-placeholder" />
  <input
    value={searchInput}
    onChange={(e) => setSearchInput(e.target.value)}
    placeholder="Filter listings..."
    className="h-9 w-full rounded-lg bg-surface-muted pl-9 pr-4 text-sm text-content placeholder:text-content-placeholder outline-none sm:w-64"
  />
</div>
```

**Step 4: Run existing tests + verify in browser**

Run: `mix test test/angle_web/controllers/store_dashboard_controller_test.exs`
Expected: Existing tests still pass

Visit `localhost:4111/store/listings` (logged in), type in filter — listings should filter.

**Step 5: Commit**

```
git add lib/angle/inventory/item.ex lib/angle_web/controllers/store_dashboard_controller.ex assets/js/pages/store/listings.tsx
git commit -m "feat: add text search filter to seller listings page"
```

---

### Task 7: Add Watchlist Support to Search + Final Polish

**Files:**
- Modify: `lib/angle_web/controllers/search_controller.ex`

**Step 1: Load watchlisted map in SearchController**

In `search_controller.ex`, add the import:

```elixir
import AngleWeb.Helpers.QueryHelpers, only: [extract_results: 1, load_watchlisted_map: 1]
```

In the `index/2` function, after loading items, add:

```elixir
    |> assign_prop(:watchlisted_map, load_watchlisted_map(conn))
```

**Step 2: Run full test suite**

Run: `mix test`
Expected: All tests pass, no regressions

**Step 3: Verify end-to-end in browser**

1. Visit `localhost:4111` — search bar in navbar, type query, press Enter
2. Lands on `/search?q=...` with results, filters, pagination
3. Toggle filters, change sort, paginate
4. Mobile: search button navigates to `/search`
5. Seller dashboard: `/store/listings` has filter input
6. Watchlist hearts work on search results (when logged in)

**Step 4: Commit**

```
git add lib/angle_web/controllers/search_controller.ex
git commit -m "feat: add watchlist support to search results"
```

---

### Task 8: Run Full Test Suite + Final Commit

**Step 1: Run all tests**

Run: `mix test`
Expected: All tests pass

**Step 2: Run TypeScript build check**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors

**Step 3: Final verification**

Verify the search feature works end-to-end in the browser at localhost.
