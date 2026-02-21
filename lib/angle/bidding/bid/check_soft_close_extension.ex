defmodule Angle.Bidding.Bid.CheckSoftCloseExtension do
  @moduledoc """
  After a bid is successfully placed, check if the auction is within 10 minutes
  of ending (soft close window). If so, extend the auction by 10 minutes to
  prevent bid sniping.

  This implements anti-sniping behavior:
  - Only extends auctions in :active status
  - Only extends if < 2 extensions have been made already
  - Extends by 10 minutes when bid is placed in last 10 minutes
  """
  use Ash.Resource.Change

  # 10 minutes in seconds
  @soft_close_window_seconds 10 * 60

  @impl true
  def change(changeset, _opts, _context) do
    # Use Ash.Changeset.after_action to register callback
    Ash.Changeset.after_action(changeset, &check_and_extend/2)
  end

  defp check_and_extend(_changeset, bid) do
    # Load the item to check auction status and end time
    item =
      Angle.Inventory.Item
      |> Ash.Query.filter(id == ^bid.item_id)
      |> Ash.Query.select([:auction_status, :end_time, :extension_count, :original_end_time])
      |> Ash.read_one!(authorize?: false)

    # Only extend active auctions that haven't reached max extensions
    if should_extend?(item) do
      case item
           |> Ash.Changeset.for_update(:extend_auction, %{minutes: 10}, authorize?: false)
           |> Ash.update() do
        {:ok, _extended_item} ->
          {:ok, bid}

        {:error, _reason} ->
          # If extension fails (e.g., race condition), still allow the bid
          # The auction will end at its current time
          {:ok, bid}
      end
    else
      {:ok, bid}
    end
  end

  defp should_extend?(item) do
    item.auction_status == :active and
      item.extension_count < 2 and
      within_soft_close_window?(item.end_time)
  end

  defp within_soft_close_window?(end_time) do
    now = DateTime.utc_now()
    time_until_end = DateTime.diff(end_time, now, :second)

    # Bid is in soft close window if time remaining is <= 10 minutes
    time_until_end > 0 and time_until_end <= @soft_close_window_seconds
  end
end
