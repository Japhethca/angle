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
  require Logger

  @popular_items_limit 50
  @log_prefix "[GeneratePopularItems]"

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("#{@log_prefix} Generating popular items")

    # Use Inventory code interface for published items with auction status filter
    {:ok, %Ash.Page.Offset{results: popular_items}} =
      Angle.Inventory.list_published_items(
        %{
          auction_statuses: [:active, :scheduled],
          sort_by: :bid_count,
          sort_order: :desc
        },
        authorize?: false,
        load: [:bid_count, :watcher_count],
        page: [limit: @popular_items_limit * 2]
      )

    # Secondary sort by watcher_count and take top N
    popular_item_ids =
      popular_items
      |> Enum.sort_by(fn item ->
        {-(item.bid_count || 0), -(item.watcher_count || 0)}
      end)
      |> Enum.take(@popular_items_limit)
      |> Enum.map(& &1.id)

    # Store only IDs in cache (not full structs) for consistency
    Cache.put_popular_items(popular_item_ids)

    Logger.info("#{@log_prefix} Cached #{length(popular_item_ids)} popular item IDs")
    :ok
  end
end
