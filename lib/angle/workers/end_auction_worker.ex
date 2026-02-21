defmodule Angle.Workers.EndAuctionWorker do
  @moduledoc """
  Oban worker that ends active auctions when their end_time arrives.

  Runs every minute via cron schedule to check for auctions that should
  transition from :active to either :ended (no bids) or :sold (has winning bid).

  Queries for items where:
  - publication_status = :published
  - auction_status = :active
  - end_time <= now (current UTC time)

  For each matching item:
  1. Determines if there's a winning bid (highest bid that meets reserve if set)
  2. Calls :end_auction action with appropriate status (:ended or :sold)

  Winner determination logic is implemented in determine_auction_status/1.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  require Ash.Query
  alias Angle.Inventory.Item
  alias Angle.Bidding.Bid

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    # Find all active auctions that should end now
    items_to_end =
      Item
      |> Ash.Query.filter(
        publication_status == :published and
          auction_status == :active and
          end_time <= ^now
      )
      |> Ash.read!(authorize?: false)

    # End each auction
    Enum.each(items_to_end, fn item ->
      status = determine_auction_status(item)

      case item
           |> Ash.Changeset.for_update(:end_auction, %{new_status: status}, authorize?: false)
           |> Ash.update() do
        {:ok, _ended_item} ->
          :ok

        {:error, error} ->
          # Log error but continue processing other items
          require Logger
          Logger.error("Failed to end auction for item #{item.id}: #{inspect(error)}")
      end
    end)

    :ok
  end

  # Determines the final auction status based on bids and reserve price.
  #
  # Returns:
  # - :ended if no bids or reserve price not met
  # - :sold if there are bids and reserve is met (or no reserve)
  #
  # Winner determination logic:
  # 1. Get highest bid for the item
  # 2. If no bids → :ended
  # 3. If reserve_price is nil → :sold (any bid wins)
  # 4. If reserve_price is set:
  #    - highest_bid >= reserve_price → :sold
  #    - otherwise → :ended
  defp determine_auction_status(item) do
    # Get highest bid for this item
    highest_bid =
      Bid
      |> Ash.Query.filter(item_id == ^item.id)
      |> Ash.Query.sort(amount: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read!(authorize?: false)
      |> List.first()

    case highest_bid do
      nil ->
        # No bids placed
        :ended

      bid ->
        # Check reserve price
        cond do
          is_nil(item.reserve_price) ->
            # No reserve, any bid wins
            :sold

          Decimal.compare(bid.amount, item.reserve_price) in [:gt, :eq] ->
            # Reserve met or exceeded
            :sold

          true ->
            # Reserve not met
            :ended
        end
    end
  end
end
