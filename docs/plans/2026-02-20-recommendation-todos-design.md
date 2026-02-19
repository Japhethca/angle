# Recommendation Engine TODO Items - Design Document

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task.

**Date:** 2026-02-20
**Status:** Design Approved
**Related PR:** #53 (feature/recommendation-engine)

## Overview

This design addresses all 10 TODO items left in the recommendation engine implementation (PR #53). The work is organized into 4 sequential phases that build progressively, following Approach 1 (Sequential by Architecture).

**Goal:** Complete the recommendation engine by adding user activity tracking, refactoring to Ash patterns, implementing proper authorization, and adding cache population jobs.

**Estimated Scope:** 30-40 files changed, ~1500 lines of code

---

## Phase 1: User Sign-in Tracking

**Goal:** Add accurate user activity tracking to improve RefreshUserInterests job efficiency.

### Problem Statement

Currently, `RefreshUserInterests` job uses `inserted_at` as a proxy for user activity because `last_sign_in_at` doesn't exist. This means the job processes all users created within the last 30 days, including inactive accounts, wasting resources on users who haven't returned.

### Solution

**1. User Resource Schema Changes**

Add two new fields to `Angle.Accounts.User`:

- `last_sign_in_at` (`:utc_datetime`) - Timestamp of most recent successful authentication
- `sign_in_count` (`:integer`, default: 0) - Total number of successful sign-ins

Both fields are nullable and optional for backward compatibility.

**2. Migration**

```sql
ALTER TABLE users
  ADD COLUMN last_sign_in_at timestamp,
  ADD COLUMN sign_in_count integer DEFAULT 0;
```

**3. Authentication Flow Integration**

Update the successful sign-in action in the User resource to:
- Set `last_sign_in_at = DateTime.utc_now()`
- Increment `sign_in_count`

This integrates with AshAuthentication's existing hooks/changes without requiring new actions.

**4. RefreshUserInterests Job Update**

Change the user filtering logic from:
```elixir
Ash.Query.filter(inserted_at > ^cutoff_date)
```

To:
```elixir
Ash.Query.filter(
  last_sign_in_at > ^cutoff_date or
  (is_nil(last_sign_in_at) and inserted_at > ^cutoff_date)
)
```

This ensures:
- Active users (with recent sign-ins) are processed
- New users (no sign-in yet) are still included
- Inactive users (old sign-in) are skipped

**5. Benefits**

- More accurate targeting of active users
- Reduces unnecessary processing by 30-50%
- Provides analytics data (sign-in counts)
- Foundation for future engagement features

### Testing

- Verify sign-in updates both fields correctly
- Test job filters active users accurately
- Test backward compatibility with NULL values
- Test new users are still processed

### Files Changed

- `lib/angle/accounts/user.ex` - Add attributes, update sign-in action
- `priv/repo/migrations/YYYYMMDDHHMMSS_add_user_sign_in_tracking.exs` - Migration
- `lib/angle/recommendations/jobs/refresh_user_interests.ex` - Update filter
- `test/angle/accounts/user_test.exs` - Add tests
- `test/angle/recommendations/jobs/refresh_user_interests_test.exs` - Update tests

---

## Phase 2: Ash Pattern Refactoring

**Goal:** Move all direct `Ash.Query`/`Ash.read` calls behind domain code interfaces, following Ash Framework best practices.

### Problem Statement

Currently, 5 modules make direct Ash calls, violating the architectural pattern where:
- Resources define `code_interface` with `define` declarations
- Domain code uses those interfaces (e.g., `Recommendations.find_similar_items(item_id)`)
- Direct Ash calls should only exist inside resource definitions

**Affected Files:**
1. `lib/angle/recommendations.ex` - Domain API
2. `lib/angle/recommendations/jobs/refresh_user_interests.ex` - Background job
3. `lib/angle/recommendations/scoring/interest_scorer.ex` - Scorer
4. `lib/angle/recommendations/scoring/recommendation_generator.ex` - Generator
5. `lib/angle/recommendations/scoring/similarity_scorer.ex` - Scorer

### Solution

**1. Add Code Interfaces to Resources**

**UserInterest** (`lib/angle/recommendations/user_interest.ex`):
```elixir
code_interface do
  domain Angle.Recommendations
  define :create_interest, action: :create
  define :upsert_interest, action: :upsert
  define :get_by_user, action: :by_user
  define :get_top_interests, action: :top_interests
end
```

**RecommendedItem** (enhance existing):
```elixir
code_interface do
  domain Angle.Recommendations
  define :create_recommendation, action: :create
  define :get_by_user, action: :by_user  # Add this
  define :upsert_recommendation, action: :upsert
end
```

**2. Update Domain API** (`lib/angle/recommendations.ex`)

Replace direct Ash calls with code interface calls:

**Before:**
```elixir
RecommendedItem
|> Ash.Query.for_read(:by_user, %{user_id: user_id, limit: limit})
|> Ash.Query.load(:item)
|> Ash.read(authorize?: false)
```

**After:**
```elixir
Angle.Recommendations.RecommendedItem.get_by_user!(
  user_id,
  %{limit: limit},
  load: [:item],
  authorize?: false
)
```

**3. Create Domain Query Helper Module**

Create `lib/angle/recommendations/queries.ex` for complex cross-domain queries:

```elixir
defmodule Angle.Recommendations.Queries do
  @moduledoc """
  Query helpers for recommendations domain.

  Encapsulates cross-domain interactions and complex queries
  used by scoring modules.
  """

  def get_user_bids(user_id, since) do
    # Encapsulates Bidding domain interaction
    Angle.Bidding.Bid
    |> Ash.Query.filter(user_id == ^user_id and bid_time > ^since)
    |> Ash.Query.load(item: [:category_id])
    |> Ash.read(authorize?: false)
  end

  def get_user_watchlist(user_id, since) do
    # Encapsulates Inventory domain interaction
    Angle.Inventory.WatchlistItem
    |> Ash.Query.filter(user_id == ^user_id and inserted_at > ^since)
    |> Ash.Query.load(item: [:category_id])
    |> Ash.read(authorize?: false)
  end

  def get_engaged_users(item_id) do
    # Cross-domain query for similarity computation
    with {:ok, bidders} <- get_item_bidders(item_id),
         {:ok, watchers} <- get_item_watchers(item_id) do
      {:ok, MapSet.union(bidders, watchers)}
    end
  end

  def get_engaged_users_batch(item_ids) do
    # Batch version to avoid N+1 queries
    with {:ok, bidders_map} <- get_batch_bidders(item_ids),
         {:ok, watchers_map} <- get_batch_watchers(item_ids) do
      merged = merge_engaged_users(bidders_map, watchers_map, item_ids)
      {:ok, merged}
    end
  end

  defp get_item_bidders(item_id) do
    case Angle.Bidding.Bid
         |> Ash.Query.filter(item_id == ^item_id)
         |> Ash.Query.select([:user_id])
         |> Ash.read(authorize?: false) do
      {:ok, bids} -> {:ok, MapSet.new(bids, & &1.user_id)}
      error -> error
    end
  end

  # ... additional helper functions
end
```

**4. Update Scoring Modules**

Refactor all three scoring modules to use `Queries` helper:

**InterestScorer** changes:
- Replace `get_user_bids/2` with `Queries.get_user_bids/2`
- Replace `get_user_watchlist/2` with `Queries.get_user_watchlist/2`

**SimilarityScorer** changes:
- Replace `get_engaged_users/1` with `Queries.get_engaged_users/1`
- Replace `get_engaged_users_batch/1` with `Queries.get_engaged_users_batch/1`

**RecommendationGenerator** changes:
- Replace direct Item queries with `Inventory.list_items_in_categories/1`
- Keep scoring logic pure (no database calls)

**5. Update RefreshUserInterests Job**

Replace direct User query with Accounts domain interface:

**Before:**
```elixir
Angle.Accounts.User
|> Ash.Query.filter(inserted_at > ^cutoff_date)
|> Ash.read(authorize?: false)
```

**After:**
```elixir
Angle.Accounts.list_active_users(since: cutoff_date)
```

Requires adding `list_active_users` action and code interface to User resource in Accounts domain.

**6. Add Code Interface to Accounts.User**

```elixir
code_interface do
  domain Angle.Accounts
  define :list_active_users, action: :list_active, args: [:since]
end

actions do
  read :list_active do
    argument :since, :utc_datetime, allow_nil?: false

    prepare fn query, _context ->
      since = Ash.Query.get_argument(query, :since)

      Ash.Query.filter(query,
        last_sign_in_at > ^since or
        (is_nil(last_sign_in_at) and inserted_at > ^since)
      )
    end
  end
end
```

### Benefits

- Follows Ash Framework architectural patterns
- Centralized query logic (easier to test/maintain)
- Clear domain boundaries
- Easier to add caching/instrumentation later
- Reduces code duplication

### Testing

- All existing tests should pass unchanged (same behavior)
- Add tests for new code interface definitions
- Add tests for `Queries` helper module
- Verify no direct Ash calls remain in scoring/domain code

### Files Changed (8-10 files)

- `lib/angle/recommendations.ex` - Use code interfaces
- `lib/angle/recommendations/queries.ex` - New helper module
- `lib/angle/recommendations/user_interest.ex` - Add code interface
- `lib/angle/recommendations/recommended_item.ex` - Enhance code interface
- `lib/angle/recommendations/scoring/interest_scorer.ex` - Use Queries helper
- `lib/angle/recommendations/scoring/similarity_scorer.ex` - Use Queries helper
- `lib/angle/recommendations/scoring/recommendation_generator.ex` - Use domain interfaces
- `lib/angle/recommendations/jobs/refresh_user_interests.ex` - Use Accounts interface
- `lib/angle/accounts/user.ex` - Add list_active action and code interface
- `test/angle/recommendations/queries_test.exs` - New tests

---

## Phase 3: Authorization Policies

**Goal:** Replace permissive `authorize_if always()` policies with proper access control for recommendation resources.

### Problem Statement

All three resources (UserInterest, ItemSimilarity, RecommendedItem) currently have wide-open policies because they were designed for "internal background job use only." However, these resources need proper authorization before being exposed via controllers or RPC endpoints.

### Solution

**1. UserInterest Resource Authorization**

**Access Rules:**
- Users can only read their own interests
- Background jobs can create/update (via `authorize?: false`)
- Admins can manage all

```elixir
policies do
  # Users can read their own interests
  policy action_type(:read) do
    authorize_if expr(user_id == ^actor(:id))
  end

  # Admin bypass for all actions
  bypass action_type([:create, :update, :destroy]) do
    authorize_if {Angle.Accounts.Checks.HasPermission, permission: "manage_recommendations"}
  end

  # Default deny write operations (background jobs use authorize?: false)
  policy action_type([:create, :update, :destroy]) do
    forbid_if always()
  end
end
```

**2. ItemSimilarity Resource Authorization**

**Access Rules:**
- Anyone can read similar items (public feature)
- Only background jobs/admins can write

```elixir
policies do
  # Anyone can read similar items
  policy action_type(:read) do
    authorize_if always()
  end

  # Admin bypass
  bypass action_type([:create, :update, :destroy]) do
    authorize_if {Angle.Accounts.Checks.HasPermission, permission: "manage_recommendations"}
  end

  # Default deny write operations (background jobs use authorize?: false)
  policy action_type([:create, :update, :destroy]) do
    forbid_if always()
  end
end
```

**3. RecommendedItem Resource Authorization**

**Access Rules:**
- Users can only read their own recommendations
- Only background jobs/admins can write

```elixir
policies do
  # Users can read their own recommendations
  policy action_type(:read) do
    authorize_if expr(user_id == ^actor(:id))
  end

  # Admin bypass
  bypass action_type([:create, :update, :destroy]) do
    authorize_if {Angle.Accounts.Checks.HasPermission, permission: "manage_recommendations"}
  end

  # Default deny write operations (background jobs use authorize?: false)
  policy action_type([:create, :update, :destroy]) do
    forbid_if always()
  end
end
```

**4. Update Domain API for User-Facing Calls**

Keep `authorize?: false` for internal/background operations, but add actor-aware versions for user-facing calls:

```elixir
# Internal use (background jobs, cache warming)
def get_homepage_recommendations(user_id, opts \\ []) do
  # Uses authorize?: false internally
end

# User-facing use (when controllers/RPC added)
def get_homepage_recommendations(user_id, actor: actor, opts: opts) do
  # Uses authorization, ensures actor can only see their own data
  RecommendedItem.get_by_user!(user_id, actor: actor, ...)
end
```

**5. Add Permission Migration**

Create `manage_recommendations` permission:

```elixir
defmodule Angle.Repo.Migrations.AddRecommendationsPermission do
  use Ecto.Migration

  def up do
    # Create permission via Ash
    Angle.Accounts.Permission.create!(%{
      name: "manage_recommendations",
      description: "Can manage recommendation data (admin only)"
    })
  end

  def down do
    # Remove permission
  end
end
```

### Benefits

- Proper security before exposing to frontend
- Users can only access their own data
- Clear separation between internal and user-facing calls
- Admin tools can manage recommendations

### Testing

- Test users can read only their own data
- Test unauthorized access is properly denied
- Test background jobs still work with `authorize?: false`
- Test admin permission grants access
- Test anonymous users cannot read any recommendations

### Files Changed (4 files)

- `lib/angle/recommendations/user_interest.ex` - Update policies
- `lib/angle/recommendations/item_similarity.ex` - Update policies
- `lib/angle/recommendations/recommended_item.ex` - Update policies
- `priv/repo/migrations/YYYYMMDDHHMMSS_add_recommendations_permission.exs` - New migration

---

## Phase 4: Cache Population Strategy

**Goal:** Implement background jobs to populate ETS caches for performance optimization, with TTL/eviction strategy.

### Problem Statement

The ETS cache infrastructure exists but nothing populates it. All domain API calls fall through to database queries, missing the performance benefits. Need:
1. Jobs to populate caches
2. TTL/eviction strategy
3. Cache warming triggers
4. Fallback for cache misses

### Solution

**1. New Job: ComputeItemSimilarities**

Populates `similar_items_cache` with pre-computed similarity scores.

```elixir
defmodule Angle.Recommendations.Jobs.ComputeItemSimilarities do
  @moduledoc """
  Background job to pre-compute item similarity scores.

  Runs daily to compute similarities for all published items and populate
  the ETS cache. Can also be triggered on-demand for specific items.

  ## Processing Strategy
  - Processes all published items in batches
  - Computes top 20 similar items per item
  - 500ms sleep between batches for rate limiting
  - Stores results in :similar_items_cache ETS table

  ## Oban Configuration
  - Queue: :recommendations_slow (expensive computation)
  - Max attempts: 3
  - Uniqueness: 12 hour period
  """

  use Oban.Worker,
    queue: :recommendations_slow,
    max_attempts: 3,
    unique: [period: :timer.hours(12)]

  alias Angle.Recommendations.{Cache, Queries}
  alias Angle.Recommendations.Scoring.SimilarityScorer

  @batch_size 50
  @batch_sleep_ms 500
  @top_similar_count 20
  @log_prefix "[ComputeItemSimilarities]"

  @doc """
  Performs similarity computation.

  ## Args
  - `%{"item_id" => id}` - Compute for specific item
  - `%{}` - Compute for all published items
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"item_id" => item_id}}) do
    Logger.info("#{@log_prefix} Computing similarities for item #{item_id}")
    compute_similarities_for_item(item_id)
  end

  def perform(%Oban.Job{args: _args}) do
    Logger.info("#{@log_prefix} Starting full similarity computation")
    compute_all_similarities()
  end

  defp compute_all_similarities do
    published_items = Angle.Inventory.list_published_items()
    total = length(published_items)

    Logger.info("#{@log_prefix} Processing #{total} items")

    published_items
    |> Enum.chunk_every(@batch_size)
    |> Enum.with_index()
    |> Enum.each(fn {batch, idx} ->
      Enum.each(batch, &compute_similarities_for_item/1)

      processed = min((idx + 1) * @batch_size, total)
      Logger.info("#{@log_prefix} Progress: #{processed}/#{total}")

      Process.sleep(@batch_sleep_ms)
    end)

    Logger.info("#{@log_prefix} Complete")
    :ok
  end

  defp compute_similarities_for_item(item_id) when is_binary(item_id) do
    with {:ok, item} <- Angle.Inventory.get_item(item_id),
         {:ok, candidates} <- get_candidate_items(item),
         {:ok, similarities} <- SimilarityScorer.compute_similarities(item, candidates) do

      # Take top N, store in cache
      top_similar =
        similarities
        |> Enum.take(@top_similar_count)
        |> Enum.map(fn {item, _score, _reason} -> item end)

      Cache.put_similar_items(item_id, top_similar)
      :ok
    else
      error ->
        Logger.warning("#{@log_prefix} Failed for item #{item_id}: #{inspect(error)}")
        :ok  # Continue processing other items
    end
  end

  defp get_candidate_items(source_item) do
    # Get items in same category + nearby price range
    Angle.Inventory.list_items_for_similarity(
      category_id: source_item.category_id,
      price_range: price_range_for(source_item.current_price)
    )
  end
end
```

**2. New Job: GeneratePopularItems**

Populates `popular_items_cache` with trending items.

```elixir
defmodule Angle.Recommendations.Jobs.GeneratePopularItems do
  @moduledoc """
  Background job to generate popular items for homepage.

  Runs hourly to compute trending items based on recent activity
  and cache results for fast homepage recommendations.

  ## Strategy
  - Selects top 50 items by bid_count + watcher_count
  - Only active/scheduled auctions
  - Only published items

  ## Oban Configuration
  - Queue: :recommendations
  - Max attempts: 3
  - Uniqueness: 1 hour period
  """

  use Oban.Worker,
    queue: :recommendations,
    max_attempts: 3,
    unique: [period: :timer.hours(1)]

  alias Angle.Recommendations.Cache

  @popular_items_limit 50
  @log_prefix "[GeneratePopularItems]"

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("#{@log_prefix} Generating popular items")

    popular_items =
      Angle.Inventory.Item
      |> Ash.Query.filter(publication_status == :published)
      |> Ash.Query.filter(auction_status in [:active, :scheduled])
      |> Ash.Query.load([:bid_count, :watcher_count])
      |> Ash.Query.sort([
        {:bid_count, :desc},
        {:watcher_count, :desc}
      ])
      |> Ash.Query.limit(@popular_items_limit)
      |> Ash.read!(authorize?: false)

    Cache.put_popular_items(popular_items)

    Logger.info("#{@log_prefix} Cached #{length(popular_items)} popular items")
    :ok
  end
end
```

**3. Enhanced Cache Module with TTL**

Add TTL tracking to cache entries:

```elixir
defmodule Angle.Recommendations.Cache do
  @moduledoc """
  ETS cache management for recommendations with TTL support.

  Tables:
    - :similar_items_cache - {item_id, {items, inserted_at}}
    - :popular_items_cache - {:homepage_popular, {items, inserted_at}}

  Cache entries include insertion timestamp for TTL-based eviction.
  """

  @default_ttl_seconds 86400  # 24 hours

  # ... existing init functions ...

  @doc """
  Get similar items from cache, respecting TTL.

  Returns {:error, :stale} if entry exists but is older than max_age.
  """
  def get_similar_items(item_id, opts \\ []) do
    max_age = Keyword.get(opts, :max_age_seconds, @default_ttl_seconds)

    case :ets.lookup(:similar_items_cache, item_id) do
      [{^item_id, {items, inserted_at}}] ->
        age_seconds = DateTime.diff(DateTime.utc_now(), inserted_at)

        if age_seconds <= max_age do
          {:ok, items}
        else
          {:error, :stale}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Store similar items in cache with current timestamp.
  """
  def put_similar_items(item_id, items) do
    :ets.insert(:similar_items_cache, {item_id, {items, DateTime.utc_now()}})
    :ok
  end

  @doc """
  Get popular items from cache, respecting TTL.
  """
  def get_popular_items(opts \\ []) do
    max_age = Keyword.get(opts, :max_age_seconds, @default_ttl_seconds)

    case :ets.lookup(:popular_items_cache, :homepage_popular) do
      [{:homepage_popular, {items, inserted_at}}] ->
        age_seconds = DateTime.diff(DateTime.utc_now(), inserted_at)

        if age_seconds <= max_age do
          {:ok, items}
        else
          {:error, :stale}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Store popular items in cache with current timestamp.
  """
  def put_popular_items(items) do
    :ets.insert(:popular_items_cache, {:homepage_popular, {items, DateTime.utc_now()}})
    :ok
  end

  @doc """
  Get cache statistics for monitoring.
  """
  def get_stats do
    %{
      similar_items_count: :ets.info(:similar_items_cache, :size),
      popular_items_cached: :ets.info(:popular_items_cache, :size),
      similar_items_memory_words: :ets.info(:similar_items_cache, :memory),
      popular_items_memory_words: :ets.info(:popular_items_cache, :memory)
    }
  end
end
```

**4. New Job: EvictStaleCache**

Periodically removes stale cache entries:

```elixir
defmodule Angle.Recommendations.Jobs.EvictStaleCache do
  @moduledoc """
  Background job to evict stale cache entries.

  Runs every 6 hours to remove entries older than 24 hours
  from both ETS cache tables.

  ## Oban Configuration
  - Queue: :recommendations
  - Max attempts: 1
  - Uniqueness: 6 hour period
  """

  use Oban.Worker,
    queue: :recommendations,
    max_attempts: 1,
    unique: [period: :timer.hours(6)]

  alias Angle.Recommendations.Cache

  @max_cache_age_seconds 86400  # 24 hours
  @log_prefix "[EvictStaleCache]"

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("#{@log_prefix} Starting cache eviction")

    before_stats = Cache.get_stats()

    evict_stale_similar_items()
    evict_stale_popular_items()

    after_stats = Cache.get_stats()

    Logger.info("#{@log_prefix} Evicted #{
      before_stats.similar_items_count - after_stats.similar_items_count
    } similar items entries")

    :ok
  end

  defp evict_stale_similar_items do
    cutoff = DateTime.add(DateTime.utc_now(), -@max_cache_age_seconds, :second)

    # ETS select_delete with matchspec
    :ets.select_delete(:similar_items_cache, [
      {{:"$1", {:"$2", :"$3"}},
       [{:<, :"$3", {:const, cutoff}}],
       [true]}
    ])
  end

  defp evict_stale_popular_items do
    cutoff = DateTime.add(DateTime.utc_now(), -@max_cache_age_seconds, :second)

    case :ets.lookup(:popular_items_cache, :homepage_popular) do
      [{:homepage_popular, {_items, inserted_at}}] ->
        if DateTime.compare(inserted_at, cutoff) == :lt do
          :ets.delete(:popular_items_cache, :homepage_popular)
        end

      [] ->
        :ok
    end
  end
end
```

**5. Update Oban Cron Configuration**

Add scheduled jobs to `config/config.exs`:

```elixir
config :angle, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [
    default: 10,
    recommendations: 10,
    recommendations_slow: 3
  ],
  repo: Angle.Repo,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       # Existing jobs
       {"0 * * * *", Angle.Recommendations.Jobs.RefreshUserInterests},

       # New cache population jobs
       {"0 * * * *", Angle.Recommendations.Jobs.GeneratePopularItems},
       {"0 2 * * *", Angle.Recommendations.Jobs.ComputeItemSimilarities},  # 2 AM daily
       {"0 */6 * * *", Angle.Recommendations.Jobs.EvictStaleCache}  # Every 6 hours
     ]}
  ]
```

**6. Update Domain API to Use Cache**

Modify domain functions to check cache first:

```elixir
def get_similar_items(item_id, opts \\ []) do
  limit = Keyword.get(opts, :limit, 10)

  case Cache.get_similar_items(item_id) do
    {:ok, cached_items} ->
      Enum.take(cached_items, limit)

    {:error, :not_found} ->
      # Cache miss: compute on-demand and store
      compute_and_cache_similar_items(item_id, limit)

    {:error, :stale} ->
      # Stale cache: return it but enqueue refresh job
      {:ok, {stale_items, _}} = Cache.get_similar_items(item_id, max_age_seconds: :infinity)
      enqueue_similarity_computation(item_id)
      Enum.take(stale_items, limit)
  end
end

defp compute_and_cache_similar_items(item_id, limit) do
  # On-demand computation fallback
  with {:ok, item} <- Angle.Inventory.get_item(item_id),
       {:ok, candidates} <- get_candidate_items(item),
       {:ok, similarities} <- SimilarityScorer.compute_similarities(item, candidates) do

    top_similar =
      similarities
      |> Enum.take(20)
      |> Enum.map(fn {item, _score, _reason} -> item end)

    Cache.put_similar_items(item_id, top_similar)
    Enum.take(top_similar, limit)
  else
    _ -> []  # Return empty on error
  end
end
```

**7. Cache Warming Triggers**

Add hooks to Item resource to warm cache on lifecycle events:

```elixir
# In Item resource
changes do
  change after_action(fn changeset, item, _context ->
    # When item is published, enqueue similarity computation
    if Ash.Changeset.changing_attribute?(changeset, :publication_status) do
      new_status = Ash.Changeset.get_attribute(changeset, :publication_status)

      if new_status == :published do
        Angle.Recommendations.Jobs.ComputeItemSimilarities.new(%{"item_id" => item.id})
        |> Oban.insert()
      end
    end

    {:ok, item}
  end), on: [:update]
end
```

### Benefits

- **Performance**: Cache hits reduce latency from 50-100ms to 1-2ms
- **Scalability**: Reduces database load by 80-90% for recommendation queries
- **Availability**: Stale data acceptable (recommendations don't need real-time accuracy)
- **Observability**: Cache stats available for monitoring

### Testing

- Test jobs populate caches correctly
- Test TTL eviction works
- Test cache hit/miss/stale behavior
- Test on-demand computation fallback
- Test cache warming triggers
- Benchmark performance improvement

### Files Changed (9 files)

- `lib/angle/recommendations/cache.ex` - Add TTL support, stats
- `lib/angle/recommendations/jobs/compute_item_similarities.ex` - New job
- `lib/angle/recommendations/jobs/generate_popular_items.ex` - New job
- `lib/angle/recommendations/jobs/evict_stale_cache.ex` - New job
- `lib/angle/recommendations.ex` - Use cache in domain API
- `lib/angle/inventory/item.ex` - Add cache warming hooks
- `config/config.exs` - Add cron schedules
- `test/angle/recommendations/cache_test.exs` - Add TTL tests
- `test/angle/recommendations/jobs/*_test.exs` - New job tests

---

## Implementation Order

**Phase 1** → **Phase 2** → **Phase 3** → **Phase 4**

Each phase should be implemented, tested, and merged before starting the next. This ensures:
- Each phase builds on a stable foundation
- Changes are reviewable in digestible chunks
- Issues are caught early before compounding

## Testing Strategy

**Unit Tests:**
- Each new module/function gets comprehensive unit tests
- Mock external dependencies (cross-domain calls)
- Test edge cases and error handling

**Integration Tests:**
- Test end-to-end flows (job → domain API → resource)
- Test cross-domain interactions
- Test authorization enforcement

**Performance Tests:**
- Benchmark cache hit vs miss latency
- Measure database load reduction
- Monitor memory usage of ETS tables

## Rollout Plan

1. **Phase 1**: Deploy immediately (backward compatible)
2. **Phase 2**: Deploy after Phase 1 merge (refactoring, no behavior change)
3. **Phase 3**: Deploy after Phase 2 merge (adds security, safe to deploy)
4. **Phase 4**: Deploy with monitoring (performance impact, reversible)

For Phase 4, consider:
- Enable cache gradually (feature flag)
- Monitor cache hit rates and performance
- Roll back if issues arise (domain API degrades gracefully to database)

## Success Metrics

**Phase 1:**
- ✅ RefreshUserInterests job processes 30-50% fewer users
- ✅ All tests pass with new sign-in tracking

**Phase 2:**
- ✅ Zero direct Ash calls in scoring modules
- ✅ All existing tests pass unchanged
- ✅ Code follows Ash patterns

**Phase 3:**
- ✅ Authorization tests pass
- ✅ Unauthorized access properly denied
- ✅ Background jobs still function

**Phase 4:**
- ✅ Cache hit rate > 80% for similar items
- ✅ Average recommendation latency < 5ms (cache hit)
- ✅ Database query count reduced by 80%+
- ✅ ETS memory usage < 100MB

## Risks and Mitigations

**Risk 1: Cache staleness causes confusing UX**
- Mitigation: Use TTL of 24 hours (acceptable for recommendations)
- Mitigation: Add manual cache invalidation if needed

**Risk 2: ETS memory growth unbounded**
- Mitigation: EvictStaleCache job runs every 6 hours
- Mitigation: Monitor memory usage, add alerts

**Risk 3: Cache warming jobs overload database**
- Mitigation: Use `recommendations_slow` queue with 3 workers
- Mitigation: Add rate limiting (500ms sleep between batches)

**Risk 4: Authorization breaks background jobs**
- Mitigation: Keep `authorize?: false` for internal operations
- Mitigation: Comprehensive tests for both paths

**Risk 5: Cross-domain refactoring causes subtle bugs**
- Mitigation: Extensive integration tests
- Mitigation: Deploy Phase 2 separately, monitor closely

## Documentation Updates

- Update `lib/angle/recommendations/README.md` with new architecture
- Document cache warming strategy and TTL behavior
- Add runbook for cache management (invalidation, stats)
- Update API documentation with authorization requirements

---

**End of Design Document**
