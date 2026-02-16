defmodule Angle.Inventory.Item.ScheduleEndAuction do
  @moduledoc """
  Ash change that schedules an Oban job to end the auction
  at the item's `end_time` when the item is published.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, item ->
      if item.end_time do
        %{item_id: item.id}
        |> Angle.Bidding.Workers.EndAuctionWorker.new(scheduled_at: item.end_time)
        |> Oban.insert!()
      end

      {:ok, item}
    end)
  end
end
