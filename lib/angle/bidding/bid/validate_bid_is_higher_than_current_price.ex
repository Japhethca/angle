defmodule Angle.Bidding.Bid.ValidateBidIsHigherThanCurrentPrice do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    # item = Ash.get(Item, Ash.Changeset.get_argument(changeset, :item_id))
    # dbg(item)
    # Ash.Changeset.add_error(changeset, amount: "Bid amount validation is not implemented yet")
    changeset
    # case Ash.Changeset.get_related(changeset, :item) do
    #   nil ->
    #     # This is a safeguard. It should not be reached if the action
    #     # correctly uses `change load(:item)` before this change.
    #     Ash.Changeset.add_error(
    #       changeset,
    #       field: :item_id,
    #       message: "was not loaded. Please ensure `load(:item)` is used in the action."
    #     )

    #   item ->
    #     with {:ok, amount} <- Ash.Changeset.get_argument(changeset, :amount) do
    #       if amount > item.current_price do
    #         changeset
    #       else
    #         error_message = "Bid amount must be greater than the current price of #{item.current_price}."
    #         Ash.Changeset.add_error(changeset, :amount, error_message)
    #       end
    #     else
    #       # This case handles when :amount is not present in the input, do nothing.
    #       _ ->
    #         changeset
    #     end
    # end
  end
end
