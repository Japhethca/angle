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
  require Ash.Query
  require Logger

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

    # Store only IDs in cache (not full structs) for consistency
    popular_item_ids = Enum.map(popular_items, & &1.id)
    Cache.put_popular_items(popular_item_ids)

    Logger.info("#{@log_prefix} Cached #{length(popular_item_ids)} popular item IDs")
    :ok
  end
end
