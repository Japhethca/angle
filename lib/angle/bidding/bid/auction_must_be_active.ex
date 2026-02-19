defmodule Angle.Bidding.Bid.AuctionMustBeActive do
  @moduledoc """
  Validates that the auction is in active or scheduled status.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    item_id = Ash.Changeset.get_attribute(changeset, :item_id)

    # Get item status
    item = Angle.Inventory.Item
      |> Ash.Query.filter(id == ^item_id)
      |> Ash.Query.select([:auction_status, :publication_status])
      |> Ash.read_one!(authorize?: false)

    cond do
      item.publication_status != :published ->
        Ash.Changeset.add_error(
          changeset,
          field: :item_id,
          message: "auction is not active"
        )

      item.auction_status not in [:active, :scheduled] ->
        Ash.Changeset.add_error(
          changeset,
          field: :item_id,
          message: "auction has ended"
        )

      true ->
        changeset
    end
  end
end
