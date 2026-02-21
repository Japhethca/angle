defmodule Angle.Bidding.Bid.PreventSelfBidding do
  @moduledoc """
  Prevents users from bidding on their own items.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    user_id = Ash.Changeset.get_attribute(changeset, :user_id)
    item_id = Ash.Changeset.get_attribute(changeset, :item_id)

    # Get item owner
    item = Angle.Inventory.Item
      |> Ash.Query.filter(id == ^item_id)
      |> Ash.Query.select([:created_by_id])
      |> Ash.read_one!(authorize?: false)

    if item.created_by_id == user_id do
      Ash.Changeset.add_error(
        changeset,
        field: :user_id,
        message: "cannot bid on your own item"
      )
    else
      changeset
    end
  end
end
