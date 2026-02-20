defmodule Angle.Bidding.Bid.CheckBlacklist do
  @moduledoc """
  Validates that the bidder is not blacklisted by the seller.

  Sellers can blacklist users who have previously caused issues (non-payment,
  disputes, etc.). This check prevents blacklisted users from placing bids on
  that specific seller's items.
  """
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    user_id = Ash.Changeset.get_attribute(changeset, :user_id)

    if is_nil(user_id) do
      changeset
    else
      check_blacklist(changeset, user_id)
    end
  end

  defp check_blacklist(changeset, user_id) do
    # Get item to find seller
    item_id = Ash.Changeset.get_attribute(changeset, :item_id)

    item =
      Angle.Inventory.Item
      |> Ash.Query.filter(id == ^item_id)
      |> Ash.Query.select([:created_by_id])
      |> Ash.read_one!(authorize?: false)

    seller_id = item.created_by_id

    # Check if user is blacklisted by this seller
    blacklist_entry =
      Angle.Bidding.SellerBlacklist
      |> Ash.Query.filter(seller_id == ^seller_id and blocked_user_id == ^user_id)
      |> Ash.read_one(authorize?: false)

    case blacklist_entry do
      {:ok, nil} ->
        # Not blacklisted
        changeset

      {:ok, _entry} ->
        # Blacklisted
        Ash.Changeset.add_error(
          changeset,
          message:
            "You are not allowed to bid on this seller's items. Please contact support if you believe this is an error."
        )

      {:error, _} ->
        # Query error, allow bid (don't block on technical error)
        changeset
    end
  end
end
