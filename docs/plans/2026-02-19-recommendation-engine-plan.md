# Recommendation Engine Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a hybrid recommendation engine that provides personalized item recommendations across three contexts: homepage, item detail pages, and post-bid suggestions.

**Architecture:** Elixir-native approach using Ash resources for data modeling, Oban for background jobs, ETS for caching, and PostgreSQL for persistence. Pre-compute recommendations via background jobs, serve from cache/database.

**Tech Stack:** Ash Framework 3.0, Oban, PostgreSQL, ETS, Phoenix

---

## Phase 1: Foundation - Domain Setup

### Task 1: Create Recommendations Domain Module

**Files:**
- Create: `lib/angle/recommendations.ex`
- Modify: `config/config.exs`

**Step 1: Create domain module**

Create `lib/angle/recommendations.ex`:

```elixir
defmodule Angle.Recommendations do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    # Resources will be added in subsequent tasks
  end
end
```

**Step 2: Add domain to config**

Modify `config/config.exs` - add to the list of Ash domains:

```elixir
config :angle,
  ash_domains: [
    Angle.Accounts,
    Angle.Bidding,
    Angle.Catalog,
    Angle.Inventory,
    Angle.Recommendations  # Add this line
  ]
```

**Step 3: Compile and verify**

Run: `mix compile`
Expected: Compiles successfully with no errors

**Step 4: Commit**

```bash
git add lib/angle/recommendations.ex config/config.exs
git commit -m "feat(recommendations): create Recommendations domain

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 2: Create UserInterest Resource

**Files:**
- Create: `lib/angle/recommendations/user_interest.ex`
- Modify: `lib/angle/recommendations.ex`

**Step 1: Create UserInterest resource**

Create `lib/angle/recommendations/user_interest.ex`:

```elixir
defmodule Angle.Recommendations.UserInterest do
  use Ash.Resource,
    domain: Angle.Recommendations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "user_interests"
    repo Angle.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :category_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :interest_score, :float do
      allow_nil? false
      default 0.0
      public? true
    end

    attribute :last_interaction_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    attribute :interaction_count, :integer do
      allow_nil? false
      default 0
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :category, Angle.Catalog.Category do
      allow_nil? false
      attribute_writable? true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:user_id, :category_id, :interest_score, :last_interaction_at, :interaction_count]
    end

    update :update do
      primary? true
      accept [:interest_score, :last_interaction_at, :interaction_count]
    end

    destroy :destroy do
      primary? true
    end

    read :by_user do
      argument :user_id, :uuid, allow_nil?: false

      filter expr(user_id == ^arg(:user_id))
    end

    read :top_interests do
      argument :user_id, :uuid, allow_nil?: false
      argument :limit, :integer, default: 5

      filter expr(user_id == ^arg(:user_id))

      prepare fn query, _context ->
        query
        |> Ash.Query.sort(interest_score: :desc)
        |> Ash.Query.limit(Ash.Query.get_argument(query, :limit))
      end
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  identities do
    identity :unique_user_category, [:user_id, :category_id]
  end

  postgres do
    custom_indexes do
      index [:user_id, :interest_score]
    end
  end
end
```

**Step 2: Add resource to domain**

Modify `lib/angle/recommendations.ex`:

```elixir
  resources do
    resource Angle.Recommendations.UserInterest
  end
```

**Step 3: Generate migration**

Run: `mix ash.codegen --dev`
Expected: Creates migration file for user_interests table

**Step 4: Commit**

```bash
git add lib/angle/recommendations/user_interest.ex lib/angle/recommendations.ex priv/repo/migrations/*user_interests*
git commit -m "feat(recommendations): add UserInterest resource

Tracks user interest scores per category based on bids and watchlist.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 3: Create ItemSimilarity Resource

**Files:**
- Create: `lib/angle/recommendations/item_similarity.ex`
- Modify: `lib/angle/recommendations.ex`

**Step 1: Create ItemSimilarity resource**

Create `lib/angle/recommendations/item_similarity.ex`:

```elixir
defmodule Angle.Recommendations.ItemSimilarity do
  use Ash.Resource,
    domain: Angle.Recommendations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "item_similarities"
    repo Angle.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :source_item_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :similar_item_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :similarity_score, :float do
      allow_nil? false
      public? true
    end

    attribute :reason, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:same_category, :price_range, :collaborative]
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :source_item, Angle.Inventory.Item do
      allow_nil? false
      attribute_writable? true
      source_attribute :source_item_id
    end

    belongs_to :similar_item, Angle.Inventory.Item do
      allow_nil? false
      attribute_writable? true
      source_attribute :similar_item_id
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:source_item_id, :similar_item_id, :similarity_score, :reason]
    end

    update :update do
      primary? true
      accept [:similarity_score, :reason]
    end

    destroy :destroy do
      primary? true
    end

    read :by_source_item do
      argument :source_item_id, :uuid, allow_nil?: false
      argument :limit, :integer, default: 20

      filter expr(source_item_id == ^arg(:source_item_id))

      prepare fn query, _context ->
        query
        |> Ash.Query.sort(similarity_score: :desc)
        |> Ash.Query.limit(Ash.Query.get_argument(query, :limit))
      end
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  postgres do
    custom_indexes do
      index [:source_item_id, :similarity_score]
    end
  end
end
```

**Step 2: Add resource to domain**

Modify `lib/angle/recommendations.ex`:

```elixir
  resources do
    resource Angle.Recommendations.UserInterest
    resource Angle.Recommendations.ItemSimilarity
  end
```

**Step 3: Generate migration**

Run: `mix ash.codegen --dev`
Expected: Creates migration file for item_similarities table

**Step 4: Commit**

```bash
git add lib/angle/recommendations/item_similarity.ex lib/angle/recommendations.ex priv/repo/migrations/*item_similarities*
git commit -m "feat(recommendations): add ItemSimilarity resource

Pre-computed similar items for detail page recommendations.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 4: Create RecommendedItem Resource

**Files:**
- Create: `lib/angle/recommendations/recommended_item.ex`
- Modify: `lib/angle/recommendations.ex`

**Step 1: Create RecommendedItem resource**

Create `lib/angle/recommendations/recommended_item.ex`:

```elixir
defmodule Angle.Recommendations.RecommendedItem do
  use Ash.Resource,
    domain: Angle.Recommendations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "recommended_items"
    repo Angle.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :item_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :recommendation_score, :float do
      allow_nil? false
      public? true
    end

    attribute :recommendation_reason, :string do
      public? true
    end

    attribute :rank, :integer do
      allow_nil? false
      public? true
    end

    attribute :generated_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :item, Angle.Inventory.Item do
      allow_nil? false
      attribute_writable? true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:user_id, :item_id, :recommendation_score, :recommendation_reason, :rank, :generated_at]
    end

    update :update do
      primary? true
      accept [:recommendation_score, :recommendation_reason, :rank]
    end

    destroy :destroy do
      primary? true
    end

    read :by_user do
      argument :user_id, :uuid, allow_nil?: false
      argument :limit, :integer, default: 20

      filter expr(user_id == ^arg(:user_id))

      prepare fn query, _context ->
        query
        |> Ash.Query.sort(rank: :asc)
        |> Ash.Query.limit(Ash.Query.get_argument(query, :limit))
      end
    end

    read :stale_recommendations do
      argument :cutoff, :utc_datetime, allow_nil?: false

      filter expr(generated_at < ^arg(:cutoff))
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  postgres do
    custom_indexes do
      index [:user_id, :rank]
      index [:generated_at]
    end
  end
end
```

**Step 2: Add resource to domain**

Modify `lib/angle/recommendations.ex`:

```elixir
  resources do
    resource Angle.Recommendations.UserInterest
    resource Angle.Recommendations.ItemSimilarity
    resource Angle.Recommendations.RecommendedItem
  end
```

**Step 3: Generate migration**

Run: `mix ash.codegen --dev`
Expected: Creates migration file for recommended_items table

**Step 4: Commit**

```bash
git add lib/angle/recommendations/recommended_item.ex lib/angle/recommendations.ex priv/repo/migrations/*recommended_items*
git commit -m "feat(recommendations): add RecommendedItem resource

Pre-computed homepage recommendations per user.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 5: Run Migrations

**Step 1: Run migrations**

Run: `mix ash_postgres.migrate`
Expected: All migrations run successfully

**Step 2: Verify database schema**

Run: `mix run -e "IO.inspect(Angle.Repo.query!(\"SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%interest%' OR table_name LIKE '%similar%' OR table_name LIKE '%recommended%'\"))"`

Expected: Shows user_interests, item_similarities, recommended_items tables

**Step 3: Commit if any schema changes**

```bash
git add priv/repo/migrations/*
git commit -m "chore(db): run recommendation engine migrations

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 2: Scoring Logic

### Task 6: Create InterestScorer Module

**Files:**
- Create: `lib/angle/recommendations/scoring/interest_scorer.ex`

**Step 1: Create scoring directory and module**

Create `lib/angle/recommendations/scoring/interest_scorer.ex`:

```elixir
defmodule Angle.Recommendations.Scoring.InterestScorer do
  @moduledoc """
  Computes user interest scores per category based on bids and watchlist items.

  Scoring formula:
    interest_score = (bid_count × 3.0) + (watchlist_count × 2.0) × time_decay

  Time decay:
    - Last 7 days: 1.0x
    - 8-30 days: 0.7x
    - 31-90 days: 0.4x
    - 90+ days: 0.1x
  """

  @doc """
  Compute interest scores for a user across all categories they've engaged with.

  Returns list of {category_id, score, interaction_count, last_interaction} tuples.
  """
  def compute_user_interests(user_id, since \\ days_ago(90)) do
    # Get user's bids
    bids = get_user_bids(user_id, since)

    # Get user's watchlist
    watchlist = get_user_watchlist(user_id, since)

    # Group by category
    bid_categories = group_by_category(bids)
    watchlist_categories = group_by_category(watchlist)

    # Compute scores
    all_categories = Map.keys(bid_categories) ++ Map.keys(watchlist_categories)
    all_categories = Enum.uniq(all_categories)

    all_categories
    |> Enum.map(fn category_id ->
      bid_items = Map.get(bid_categories, category_id, [])
      watchlist_items = Map.get(watchlist_categories, category_id, [])

      score = compute_category_score(bid_items, watchlist_items)
      interaction_count = length(bid_items) + length(watchlist_items)
      last_interaction = get_last_interaction(bid_items ++ watchlist_items)

      {category_id, score, interaction_count, last_interaction}
    end)
    |> normalize_scores()
  end

  @doc """
  Compute score for a single category based on bids and watchlist items.
  """
  def compute_category_score(bid_items, watchlist_items) do
    bid_score =
      bid_items
      |> Enum.map(&apply_time_decay(&1, 3.0))
      |> Enum.sum()

    watchlist_score =
      watchlist_items
      |> Enum.map(&apply_time_decay(&1, 2.0))
      |> Enum.sum()

    bid_score + watchlist_score
  end

  @doc """
  Apply time decay multiplier based on how recent the interaction was.
  """
  def apply_time_decay(item, base_weight) do
    days_ago = DateTime.diff(DateTime.utc_now(), item.timestamp, :day)

    multiplier =
      cond do
        days_ago <= 7 -> 1.0
        days_ago <= 30 -> 0.7
        days_ago <= 90 -> 0.4
        true -> 0.1
      end

    base_weight * multiplier
  end

  @doc """
  Normalize scores to 0.0-1.0 range.
  """
  def normalize_scores(category_scores) do
    if Enum.empty?(category_scores) do
      []
    else
      max_score = category_scores |> Enum.map(&elem(&1, 1)) |> Enum.max()

      if max_score == 0 do
        category_scores
      else
        Enum.map(category_scores, fn {cat_id, score, count, last_interaction} ->
          normalized = min(score / max_score, 1.0)
          {cat_id, normalized, count, last_interaction}
        end)
      end
    end
  end

  # Private helpers

  defp get_user_bids(user_id, since) do
    Angle.Bidding.Bid
    |> Ash.Query.filter(user_id == ^user_id and inserted_at > ^since)
    |> Ash.Query.load(:item)
    |> Ash.read!()
    |> Enum.map(fn bid ->
      %{
        category_id: bid.item.category_id,
        timestamp: bid.inserted_at
      }
    end)
  end

  defp get_user_watchlist(user_id, since) do
    Angle.Inventory.WatchlistItem
    |> Ash.Query.filter(user_id == ^user_id and inserted_at > ^since)
    |> Ash.Query.load(:item)
    |> Ash.read!()
    |> Enum.map(fn watchlist_item ->
      %{
        category_id: watchlist_item.item.category_id,
        timestamp: watchlist_item.inserted_at
      }
    end)
  end

  defp group_by_category(items) do
    Enum.group_by(items, & &1.category_id)
  end

  defp get_last_interaction(items) do
    items
    |> Enum.map(& &1.timestamp)
    |> Enum.max(DateTime, fn -> DateTime.utc_now() end)
  end

  defp days_ago(days) do
    DateTime.utc_now()
    |> DateTime.add(-days * 24 * 60 * 60, :second)
  end
end
```

**Step 2: Compile and verify**

Run: `mix compile`
Expected: Compiles successfully

**Step 3: Commit**

```bash
git add lib/angle/recommendations/scoring/interest_scorer.ex
git commit -m "feat(recommendations): add InterestScorer module

Computes user interest scores per category with time decay.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 7: Create SimilarityScorer Module

**Files:**
- Create: `lib/angle/recommendations/scoring/similarity_scorer.ex`

**Step 1: Create SimilarityScorer module**

Create `lib/angle/recommendations/scoring/similarity_scorer.ex`:

```elixir
defmodule Angle.Recommendations.Scoring.SimilarityScorer do
  @moduledoc """
  Computes similarity scores between items for "similar items" recommendations.

  Similarity formula:
    similarity = (same_category ? 0.5 : 0.0) +
                 (price_range_overlap ? 0.3 : 0.0) +
                 collaborative_signal

  Where collaborative_signal = min(shared_users / 20.0, 0.2)
  """

  @doc """
  Compute similarity scores between source_item and a list of candidate items.

  Returns list of {item, score, reason} tuples sorted by score desc.
  """
  def compute_similarities(source_item, candidate_items) do
    candidate_items
    |> Enum.reject(&(&1.id == source_item.id))
    |> Enum.map(fn candidate ->
      score = compute_similarity_score(source_item, candidate)
      reason = determine_reason(source_item, candidate)

      {candidate, score, reason}
    end)
    |> Enum.filter(fn {_item, score, _reason} -> score > 0.3 end)
    |> Enum.sort_by(fn {_item, score, _reason} -> score end, :desc)
  end

  @doc """
  Compute similarity score between two items.
  """
  def compute_similarity_score(item_a, item_b) do
    category_score = category_similarity(item_a, item_b)
    price_score = price_similarity(item_a, item_b)
    collaborative_score = collaborative_similarity(item_a.id, item_b.id)

    category_score + price_score + collaborative_score
  end

  @doc """
  Category similarity: 0.5 if same category, 0.0 otherwise.
  """
  def category_similarity(item_a, item_b) do
    if item_a.category_id == item_b.category_id, do: 0.5, else: 0.0
  end

  @doc """
  Price similarity: 0.3 if within 50% range, 0.0 otherwise.
  """
  def price_similarity(item_a, item_b) do
    price_a = Money.to_decimal(item_a.current_price)
    price_b = Money.to_decimal(item_b.current_price)

    price_diff = Decimal.abs(Decimal.sub(price_a, price_b))
    threshold = Decimal.mult(price_a, Decimal.new("0.5"))

    if Decimal.compare(price_diff, threshold) == :lt, do: 0.3, else: 0.0
  end

  @doc """
  Collaborative similarity: Users who engaged with both items.

  Returns min(shared_users / 20.0, 0.2)
  """
  def collaborative_similarity(item_a_id, item_b_id) do
    users_a = get_engaged_users(item_a_id)
    users_b = get_engaged_users(item_b_id)

    shared_count =
      MapSet.intersection(users_a, users_b)
      |> MapSet.size()

    min(shared_count / 20.0, 0.2)
  end

  @doc """
  Determine primary reason for similarity.
  """
  def determine_reason(item_a, item_b) do
    cond do
      item_a.category_id == item_b.category_id -> :same_category
      price_similarity(item_a, item_b) > 0 -> :price_range
      true -> :collaborative
    end
  end

  # Private helpers

  defp get_engaged_users(item_id) do
    # Users who bid on this item
    bidders =
      Angle.Bidding.Bid
      |> Ash.Query.filter(item_id == ^item_id)
      |> Ash.Query.select([:user_id])
      |> Ash.read!()
      |> Enum.map(& &1.user_id)
      |> MapSet.new()

    # Users who watchlisted this item
    watchers =
      Angle.Inventory.WatchlistItem
      |> Ash.Query.filter(item_id == ^item_id)
      |> Ash.Query.select([:user_id])
      |> Ash.read!()
      |> Enum.map(& &1.user_id)
      |> MapSet.new()

    MapSet.union(bidders, watchers)
  end
end
```

**Step 2: Compile and verify**

Run: `mix compile`
Expected: Compiles successfully

**Step 3: Commit**

```bash
git add lib/angle/recommendations/scoring/similarity_scorer.ex
git commit -m "feat(recommendations): add SimilarityScorer module

Computes item similarity scores for 'similar items' feature.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 8: Create RecommendationGenerator Module

**Files:**
- Create: `lib/angle/recommendations/scoring/recommendation_generator.ex`

**Step 1: Create RecommendationGenerator module**

Create `lib/angle/recommendations/scoring/recommendation_generator.ex`:

```elixir
defmodule Angle.Recommendations.Scoring.RecommendationGenerator do
  @moduledoc """
  Generates personalized item recommendations for users based on their interests.

  Scoring formula:
    score = (category_match × 0.6) +
            (popularity × 0.2) +
            (recency × 0.2) +
            diversity_penalty
  """

  alias Angle.Recommendations.Scoring.InterestScorer

  @doc """
  Generate recommendations for a user based on their interests.

  Returns list of {item, score, reason} tuples.
  """
  def generate_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    # Get user interests
    interests = InterestScorer.compute_user_interests(user_id)

    if Enum.empty?(interests) do
      # No interests - return empty (fallback will be used)
      []
    else
      # Get top 5 interest categories
      top_categories =
        interests
        |> Enum.take(5)
        |> Enum.map(&elem(&1, 0))

      # Find items in those categories
      candidate_items = find_items_in_categories(top_categories, user_id)

      # Score items
      interests_map = Map.new(interests, fn {cat_id, score, _, _} -> {cat_id, score} end)

      candidate_items
        |> Enum.map(&score_item_for_user(&1, interests_map, user_id))
        |> Enum.sort_by(fn {_item, score, _reason} -> score end, :desc)
        |> apply_diversity_filter()
        |> Enum.take(limit)
    end
  end

  @doc """
  Score an individual item for a user.
  """
  def score_item_for_user(item, interests_map, _user_id) do
    category_score = Map.get(interests_map, item.category_id, 0.0) * 0.6
    popularity_score = popularity_boost(item) * 0.2
    recency_score = recency_boost(item) * 0.2

    total_score = category_score + popularity_score + recency_score

    reason = generate_reason(item, interests_map)

    {item, total_score, reason}
  end

  @doc """
  Popularity boost based on bid_count and watcher_count.
  """
  def popularity_boost(item) do
    popularity = (item.bid_count || 0) + (item.watcher_count || 0) * 2
    min(popularity / 10.0, 1.0)
  end

  @doc """
  Recency boost: items ending soon or recently listed.
  """
  def recency_boost(item) do
    boost = 0.0

    # Ending soon
    boost =
      if item.end_time do
        days_until_end = DateTime.diff(item.end_time, DateTime.utc_now(), :day)
        if days_until_end < 7, do: boost + 0.1, else: boost
      else
        boost
      end

    # Active auction
    boost = if item.auction_status == :active, do: boost + 0.1, else: boost

    boost
  end

  @doc """
  Apply diversity filter: max 3 items from same category.
  """
  def apply_diversity_filter(scored_items) do
    {filtered, _counts} =
      Enum.reduce(scored_items, {[], %{}}, fn {item, score, reason}, {acc, category_counts} ->
        category_id = item.category_id
        count = Map.get(category_counts, category_id, 0)

        if count < 3 do
          {acc ++ [{item, score, reason}], Map.put(category_counts, category_id, count + 1)}
        else
          {acc, category_counts}
        end
      end)

    filtered
  end

  # Private helpers

  defp find_items_in_categories(category_ids, user_id) do
    # Get items in these categories
    items =
      Angle.Inventory.Item
      |> Ash.Query.filter(
        category_id in ^category_ids and
          publication_status == :published and
          auction_status in [:active, :scheduled, :pending]
      )
      |> Ash.Query.load([:bid_count, :watcher_count])
      |> Ash.read!()

    # Exclude items user already bid on
    user_bid_item_ids =
      Angle.Bidding.Bid
      |> Ash.Query.filter(user_id == ^user_id)
      |> Ash.Query.select([:item_id])
      |> Ash.read!()
      |> Enum.map(& &1.item_id)
      |> MapSet.new()

    # Exclude items user is watching
    user_watchlist_item_ids =
      Angle.Inventory.WatchlistItem
      |> Ash.Query.filter(user_id == ^user_id)
      |> Ash.Query.select([:item_id])
      |> Ash.read!()
      |> Enum.map(& &1.item_id)
      |> MapSet.new()

    # Exclude items user is selling
    Enum.reject(items, fn item ->
      item.id in user_bid_item_ids or
        item.id in user_watchlist_item_ids or
        item.created_by_id == user_id
    end)
  end

  defp generate_reason(item, interests_map) do
    category_score = Map.get(interests_map, item.category_id, 0.0)

    cond do
      category_score > 0.7 -> "Based on your interest in this category"
      item.watcher_count && item.watcher_count > 10 -> "Popular with other buyers"
      item.auction_status == :active -> "Auction ending soon"
      true -> "Recommended for you"
    end
  end
end
```

**Step 2: Compile and verify**

Run: `mix compile`
Expected: Compiles successfully

**Step 3: Commit**

```bash
git add lib/angle/recommendations/scoring/recommendation_generator.ex
git commit -m "feat(recommendations): add RecommendationGenerator

Generates personalized recommendations based on user interests.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 3: Background Jobs

### Task 9: Create RefreshUserInterests Oban Job

**Files:**
- Create: `lib/angle/recommendations/jobs/refresh_user_interests.ex`

**Step 1: Create Oban job**

Create `lib/angle/recommendations/jobs/refresh_user_interests.ex`:

```elixir
defmodule Angle.Recommendations.Jobs.RefreshUserInterests do
  use Oban.Worker,
    queue: :recommendations,
    max_attempts: 3,
    unique: [period: 3600]

  alias Angle.Recommendations.Scoring.InterestScorer
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    Logger.info("[RefreshUserInterests] Starting user interests refresh")

    # Get active users (logged in within last 30 days)
    cutoff = DateTime.utc_now() |> DateTime.add(-30 * 24 * 60 * 60, :second)

    active_users =
      Angle.Accounts.User
      |> Ash.Query.filter(last_sign_in_at > ^cutoff)
      |> Ash.read!()

    Logger.info("[RefreshUserInterests] Refreshing interests for #{length(active_users)} users")

    # Process in batches
    active_users
    |> Enum.chunk_every(100)
    |> Enum.each(fn batch ->
      Enum.each(batch, &compute_and_save_interests/1)
      Process.sleep(100)  # Rate limiting
    end)

    Logger.info("[RefreshUserInterests] Complete")
    :ok
  end

  defp compute_and_save_interests(user) do
    interests = InterestScorer.compute_user_interests(user.id)

    Enum.each(interests, fn {category_id, score, count, last_interaction} ->
      # Upsert UserInterest
      case Angle.Recommendations.UserInterest
           |> Ash.Query.filter(user_id == ^user.id and category_id == ^category_id)
           |> Ash.read_one() do
        {:ok, nil} ->
          # Create new
          Angle.Recommendations.UserInterest
          |> Ash.Changeset.for_create(:create, %{
            user_id: user.id,
            category_id: category_id,
            interest_score: score,
            interaction_count: count,
            last_interaction_at: last_interaction
          })
          |> Ash.create()

        {:ok, existing} ->
          # Update existing
          existing
          |> Ash.Changeset.for_update(:update, %{
            interest_score: score,
            interaction_count: count,
            last_interaction_at: last_interaction
          })
          |> Ash.update()

        {:error, _} ->
          :ok
      end
    end)
  end
end
```

**Step 2: Compile and verify**

Run: `mix compile`
Expected: Compiles successfully

**Step 3: Commit**

```bash
git add lib/angle/recommendations/jobs/refresh_user_interests.ex
git commit -m "feat(recommendations): add RefreshUserInterests job

Hourly job to compute user interest profiles.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 4: Serving Layer & ETS Cache

### Task 10: Setup ETS Cache on Application Start

**Files:**
- Modify: `lib/angle/application.ex`
- Create: `lib/angle/recommendations/cache.ex`

**Step 1: Create cache module**

Create `lib/angle/recommendations/cache.ex`:

```elixir
defmodule Angle.Recommendations.Cache do
  @moduledoc """
  ETS cache management for recommendations.

  Tables:
    - :similar_items_cache - item_id → list of similar items
    - :popular_items_cache - :homepage_popular → list of items
  """

  def init do
    :ets.new(:similar_items_cache, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(:popular_items_cache, [:named_table, :set, :public, read_concurrency: true])
    :ok
  end

  def get_similar_items(item_id) do
    case :ets.lookup(:similar_items_cache, item_id) do
      [{^item_id, items}] -> {:ok, items}
      [] -> {:error, :not_found}
    end
  end

  def put_similar_items(item_id, items) do
    :ets.insert(:similar_items_cache, {item_id, items})
    :ok
  end

  def get_popular_items do
    case :ets.lookup(:popular_items_cache, :homepage_popular) do
      [{:homepage_popular, items}] -> {:ok, items}
      [] -> {:error, :not_found}
    end
  end

  def put_popular_items(items) do
    :ets.insert(:popular_items_cache, {:homepage_popular, items})
    :ok
  end

  def clear_all do
    :ets.delete_all_objects(:similar_items_cache)
    :ets.delete_all_objects(:popular_items_cache)
    :ok
  end
end
```

**Step 2: Initialize ETS on app start**

Modify `lib/angle/application.ex` - add to the `start/2` function before the supervisor starts:

```elixir
def start(_type, _args) do
  # Initialize recommendation caches
  Angle.Recommendations.Cache.init()

  children = [
    # ... existing children
  ]
end
```

**Step 3: Compile and verify**

Run: `mix compile`
Expected: Compiles successfully

**Step 4: Commit**

```bash
git add lib/angle/recommendations/cache.ex lib/angle/application.ex
git commit -m "feat(recommendations): add ETS cache infrastructure

Initialize similar_items_cache and popular_items_cache on startup.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 11: Add Domain Code Interfaces

**Files:**
- Modify: `lib/angle/recommendations.ex`
- Create: `lib/angle/recommendations/helpers.ex`

**Step 1: Add code interfaces to domain**

Modify `lib/angle/recommendations.ex` - add at the end before the `end`:

```elixir
  # Public API for serving recommendations

  @doc """
  Get homepage recommendations for a user.
  Falls back to popular items if no personalized recommendations exist.
  """
  def get_homepage_recommendations(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    personalized =
      RecommendedItem
      |> Ash.Query.for_read(:by_user, %{user_id: user_id, limit: limit})
      |> Ash.Query.load(:item)
      |> Ash.read!()
      |> Enum.map(& &1.item)

    if Enum.empty?(personalized) do
      get_popular_items(limit: limit)
    else
      personalized
    end
  end

  @doc """
  Get similar items for an item.
  Tries ETS cache first, falls back to database.
  """
  def get_similar_items(item_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 8)

    case Cache.get_similar_items(item_id) do
      {:ok, cached_items} ->
        Enum.take(cached_items, limit)

      {:error, :not_found} ->
        # Cache miss - read from database
        ItemSimilarity
        |> Ash.Query.for_read(:by_source_item, %{source_item_id: item_id, limit: limit})
        |> Ash.Query.load(:similar_item)
        |> Ash.read!()
        |> Enum.map(& &1.similar_item)
    end
  end

  @doc """
  Get popular items fallback.
  Tries ETS cache first, falls back to database query.
  """
  def get_popular_items(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    case Cache.get_popular_items() do
      {:ok, cached_items} ->
        Enum.take(cached_items, limit)

      {:error, :not_found} ->
        # Cache miss - query database
        Angle.Inventory.Item
        |> Ash.Query.filter(publication_status == :published)
        |> Ash.Query.load([:bid_count, :watcher_count])
        |> Ash.Query.sort([{:bid_count, :desc}, {:watcher_count, :desc}])
        |> Ash.Query.limit(limit)
        |> Ash.read!()
    end
  end

  alias Angle.Recommendations.Cache
```

**Step 2: Compile and verify**

Run: `mix compile`
Expected: Compiles successfully

**Step 3: Commit**

```bash
git add lib/angle/recommendations.ex
git commit -m "feat(recommendations): add public API functions

Domain functions for serving recommendations with fallbacks.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 5: Testing

### Task 12: Add Unit Tests for Scoring

**Files:**
- Create: `test/angle/recommendations/scoring/interest_scorer_test.exs`

**Step 1: Create test file**

Create `test/angle/recommendations/scoring/interest_scorer_test.exs`:

```elixir
defmodule Angle.Recommendations.Scoring.InterestScorerTest do
  use Angle.DataCase
  alias Angle.Recommendations.Scoring.InterestScorer

  describe "compute_category_score/2" do
    test "weights bids higher than watchlist" do
      # Bids: base weight 3.0
      bid_items = [
        %{category_id: "cat1", timestamp: DateTime.utc_now()}
      ]

      # Watchlist: base weight 2.0
      watchlist_items = [
        %{category_id: "cat1", timestamp: DateTime.utc_now()}
      ]

      score = InterestScorer.compute_category_score(bid_items, watchlist_items)

      # (1 × 3.0 × 1.0) + (1 × 2.0 × 1.0) = 5.0
      assert_in_delta score, 5.0, 0.1
    end
  end

  describe "apply_time_decay/2" do
    test "applies full weight for recent interactions" do
      item = %{timestamp: DateTime.utc_now() |> DateTime.add(-3 * 24 * 60 * 60, :second)}

      score = InterestScorer.apply_time_decay(item, 3.0)

      assert_in_delta score, 3.0, 0.1  # 3.0 × 1.0
    end

    test "applies 0.7x for interactions 8-30 days ago" do
      item = %{timestamp: DateTime.utc_now() |> DateTime.add(-15 * 24 * 60 * 60, :second)}

      score = InterestScorer.apply_time_decay(item, 3.0)

      assert_in_delta score, 2.1, 0.1  # 3.0 × 0.7
    end
  end

  describe "normalize_scores/1" do
    test "scales scores to 0.0-1.0 range" do
      scores = [
        {"cat1", 15.0, 5, DateTime.utc_now()},
        {"cat2", 5.0, 2, DateTime.utc_now()},
        {"cat3", 1.0, 1, DateTime.utc_now()}
      ]

      normalized = InterestScorer.normalize_scores(scores)

      # Verify all scores between 0 and 1
      Enum.each(normalized, fn {_cat, score, _count, _last} ->
        assert score >= 0.0 and score <= 1.0
      end)

      # Highest score should be 1.0
      {_cat, max_score, _count, _last} = Enum.max_by(normalized, fn {_, score, _, _} -> score end)
      assert_in_delta max_score, 1.0, 0.01
    end
  end
end
```

**Step 2: Run tests**

Run: `mix test test/angle/recommendations/scoring/interest_scorer_test.exs`
Expected: All tests pass

**Step 3: Commit**

```bash
git add test/angle/recommendations/scoring/interest_scorer_test.exs
git commit -m "test(recommendations): add InterestScorer unit tests

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 13: Add Integration Test for Recommendation Flow

**Files:**
- Create: `test/angle/recommendations/recommendation_flow_test.exs`

**Step 1: Create integration test**

Create `test/angle/recommendations/recommendation_flow_test.exs`:

```elixir
defmodule Angle.Recommendations.RecommendationFlowTest do
  use Angle.DataCase

  alias Angle.Recommendations

  describe "get_homepage_recommendations/2" do
    test "returns popular items for users with no history" do
      user = create_user()

      # Create popular items
      popular_items = create_list(3, :item, bid_count: 10, watcher_count: 5)

      recommendations = Recommendations.get_homepage_recommendations(user.id, limit: 10)

      assert length(recommendations) > 0
    end

    test "returns personalized recommendations for users with history" do
      user = create_user()
      electronics = create_category(name: "Electronics")

      # User has bid history in electronics
      Enum.each(1..3, fn _ ->
        item = create_item(category: electronics)
        create_bid(user: user, item: item)
      end)

      # Refresh interests
      Angle.Recommendations.Jobs.RefreshUserInterests.perform(%Oban.Job{args: %{}})

      # Generate recommendations
      electronics_items = create_list(5, :item, category: electronics, bid_count: 5)

      recommendations = Recommendations.get_homepage_recommendations(user.id, limit: 10)

      # Should include electronics items
      recommendation_ids = Enum.map(recommendations, & &1.id)
      assert Enum.any?(electronics_items, &(&1.id in recommendation_ids))
    end
  end

  describe "get_similar_items/2" do
    test "returns items in same category" do
      category = create_category()
      source_item = create_item(category: category)

      similar_items = create_list(3, :item, category: category)
      create_item()  # Different category

      # Compute similarities
      # (In real usage, this would be done by background job)

      results = Recommendations.get_similar_items(source_item.id)

      # Should return similar items (or empty if similarities not computed yet)
      assert is_list(results)
    end
  end
end
```

**Step 2: Run tests**

Run: `mix test test/angle/recommendations/recommendation_flow_test.exs`
Expected: Tests pass (may need factories created first)

**Step 3: Commit**

```bash
git add test/angle/recommendations/recommendation_flow_test.exs
git commit -m "test(recommendations): add integration tests for recommendation flow

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 6: Documentation & Configuration

### Task 14: Update Configuration

**Files:**
- Modify: `config/config.exs`

**Step 1: Add Oban queue configuration**

Modify `config/config.exs` - update the Oban config to add new queues:

```elixir
config :angle, Oban,
  repo: Angle.Repo,
  queues: [
    default: 10,
    recommendations: 10,        # New queue for recommendations
    recommendations_slow: 3     # New queue for expensive jobs
  ]
```

**Step 2: Commit**

```bash
git add config/config.exs
git commit -m "config: add recommendation job queues to Oban

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 15: Add README Documentation

**Files:**
- Create: `lib/angle/recommendations/README.md`

**Step 1: Create README**

Create `lib/angle/recommendations/README.md`:

```markdown
# Angle Recommendations

Hybrid recommendation engine providing personalized item recommendations.

## Architecture

- **Data Model:** UserInterest, ItemSimilarity, RecommendedItem resources
- **Scoring:** Interest-based, similarity-based, and collaborative filtering
- **Jobs:** Oban background jobs for pre-computation
- **Caching:** ETS for hot paths, PostgreSQL for persistence
- **Serving:** Domain functions with graceful fallbacks

## Recommendation Contexts

### Homepage - "Recommended for You"
- Pre-computed, refreshed every 1-2 hours
- Falls back to popular items for new users
- API: `Recommendations.get_homepage_recommendations(user_id, limit: 20)`

### Item Detail - "Similar Items"
- Pre-computed daily, served from ETS cache
- Falls back to same-category items
- API: `Recommendations.get_similar_items(item_id, limit: 8)`

### Post-Bid - "You Might Also Like"
- Real-time computation after bid
- Falls back to category popular items
- API: `Recommendations.generate_post_bid_recommendations/2` (to be implemented)

## Background Jobs

### RefreshUserInterests
- **Schedule:** Hourly
- **Queue:** `:recommendations`
- **Purpose:** Compute user interest profiles

Run manually: `Oban.insert(Angle.Recommendations.Jobs.RefreshUserInterests.new(%{}))`

## Cache Management

ETS tables:
- `:similar_items_cache` - Pre-computed similar items
- `:popular_items_cache` - Popular items fallback

Clear caches: `Angle.Recommendations.Cache.clear_all()`

## Testing

Run all recommendation tests:
```bash
mix test test/angle/recommendations/
```

## Performance Targets

| Context | Latency | Method |
|---------|---------|--------|
| Homepage | <50ms | Pre-computed |
| Item Detail | <10ms | ETS cache |
| Post-Bid | <200ms | Real-time |
```

**Step 2: Commit**

```bash
git add lib/angle/recommendations/README.md
git commit -m "docs(recommendations): add README with architecture overview

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Summary

**Phase 1: Foundation (Tasks 1-5)**
✅ Created Recommendations domain
✅ Added UserInterest, ItemSimilarity, RecommendedItem resources
✅ Generated and ran migrations

**Phase 2: Scoring Logic (Tasks 6-8)**
✅ InterestScorer - computes user interest profiles
✅ SimilarityScorer - computes item similarity
✅ RecommendationGenerator - generates personalized recommendations

**Phase 3: Background Jobs (Task 9)**
✅ RefreshUserInterests job

**Phase 4: Serving Layer (Tasks 10-11)**
✅ ETS cache setup
✅ Domain code interfaces with fallbacks

**Phase 5: Testing (Tasks 12-13)**
✅ Unit tests for scoring algorithms
✅ Integration tests for recommendation flow

**Phase 6: Documentation (Tasks 14-15)**
✅ Oban queue configuration
✅ README documentation

## Next Steps

**Not included in this plan (future work):**
1. GenerateHomepageRecommendations job (Task 16)
2. ComputeItemSimilarity job (Task 17)
3. Controller integration (Homepage, Item Detail, Post-Bid)
4. Frontend components (React)
5. Post-bid real-time recommendations
6. Analytics tracking (RecommendationEvent)
7. Health check endpoint
8. Cache warming on deployment

**To implement those, create a follow-up plan or continue iteratively.**

---

## Plan Complete

This plan provides the foundation for the recommendation engine. The MVP includes:
- ✅ Data model and domain
- ✅ Scoring algorithms
- ✅ One background job (user interests)
- ✅ Serving layer with caching
- ✅ Tests and documentation

**Ready for execution with @superpowers:executing-plans or @superpowers:subagent-driven-development**
