defmodule Angle.Workers.StartAuctionWorker do
  @moduledoc """
  Oban worker that starts scheduled auctions when their start_time arrives.

  Runs every minute via cron schedule to check for auctions that should
  transition from :scheduled to :active status.

  Queries for items where:
  - publication_status = :published
  - auction_status = :scheduled
  - start_time <= now (current UTC time)

  For each matching item, calls the :start_auction action to transition
  the auction to :active status.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  require Ash.Query
  alias Angle.Inventory.Item

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    # Find all scheduled auctions that should start now
    items_to_start =
      Item
      |> Ash.Query.filter(
        publication_status == :published and
          auction_status == :scheduled and
          start_time <= ^now
      )
      |> Ash.read!(authorize?: false)

    # Start each auction
    Enum.each(items_to_start, fn item ->
      case item
           |> Ash.Changeset.for_update(:start_auction)
           |> Ash.update(authorize?: false) do
        {:ok, _started_item} ->
          :ok

        {:error, error} ->
          # Log error but continue processing other items
          require Logger
          Logger.error("Failed to start auction for item #{item.id}: #{inspect(error)}")
      end
    end)

    :ok
  end
end
