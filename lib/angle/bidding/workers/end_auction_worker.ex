defmodule Angle.Bidding.Workers.EndAuctionWorker do
  @moduledoc """
  Oban worker that runs when an item's `end_time` passes.

  It determines the winner (highest bid), creates an Order, and
  updates the item's `auction_status` to `:sold` or `:ended`.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"item_id" => item_id}}) do
    case Ash.get(Angle.Inventory.Item, item_id, authorize?: false, load: [:bids]) do
      {:ok, item} -> end_auction(item)
      {:error, _} -> {:error, "Item not found: #{item_id}"}
    end
  end

  defp end_auction(%{auction_status: status}) when status in [:ended, :sold, :cancelled] do
    :ok
  end

  defp end_auction(item) do
    case find_winning_bid(item.bids) do
      nil -> end_without_winner(item)
      winning_bid -> end_with_winner(item, winning_bid)
    end
  end

  defp find_winning_bid([]), do: nil

  defp find_winning_bid(bids) do
    Enum.max_by(bids, & &1.amount, Decimal)
  end

  defp end_without_winner(item) do
    item
    |> Ash.Changeset.for_update(:end_auction, %{new_status: :ended}, authorize?: false)
    |> Ash.update!(authorize?: false)

    :ok
  end

  defp end_with_winner(item, winning_bid) do
    Angle.Repo.transaction(fn ->
      Angle.Bidding.Order
      |> Ash.Changeset.for_create(
        :create,
        %{
          amount: winning_bid.amount,
          item_id: item.id,
          buyer_id: winning_bid.user_id,
          seller_id: item.created_by_id
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

      item
      |> Ash.Changeset.for_update(:end_auction, %{new_status: :sold}, authorize?: false)
      |> Ash.update!(authorize?: false)
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
