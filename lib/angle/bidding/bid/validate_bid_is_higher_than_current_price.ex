defmodule Angle.Bidding.Bid.ValidateBidIsHigherThanCurrentPrice do
  @moduledoc """
  Validates that a bid amount is higher than the item's current price.

  If the item has a `current_price` (i.e., previous bids exist), the bid amount
  must be strictly greater than the current price.

  If the item has no `current_price` (i.e., no bids yet), the bid amount must be
  greater than or equal to the `starting_price`.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    item_id = Ash.Changeset.get_attribute(changeset, :item_id)
    amount = Ash.Changeset.get_attribute(changeset, :amount)

    if is_nil(item_id) or is_nil(amount) do
      changeset
    else
      validate_bid_amount(changeset, item_id, amount)
    end
  end

  defp validate_bid_amount(changeset, item_id, amount) do
    case Ash.get(Angle.Inventory.Item, item_id, authorize?: false) do
      {:ok, item} ->
        compare_against_price(changeset, item, amount)

      {:error, _} ->
        Ash.Changeset.add_error(changeset, field: :item_id, message: "item not found")
    end
  end

  defp compare_against_price(changeset, item, amount) do
    if is_nil(item.current_price) do
      validate_against_starting_price(changeset, item, amount)
    else
      validate_against_current_price(changeset, item, amount)
    end
  end

  defp validate_against_starting_price(changeset, item, amount) do
    case Decimal.compare(amount, item.starting_price) do
      :lt ->
        Ash.Changeset.add_error(changeset,
          field: :amount,
          message: "must be greater than or equal to the starting price of #{item.starting_price}"
        )

      _ ->
        changeset
    end
  end

  defp validate_against_current_price(changeset, item, amount) do
    case Decimal.compare(amount, item.current_price) do
      :gt ->
        changeset

      _ ->
        Ash.Changeset.add_error(changeset,
          field: :amount,
          message: "must be greater than the current price of #{item.current_price}"
        )
    end
  end
end
