defmodule Angle.Bidding.Bid.ValidateBidIncrement do
  @moduledoc """
  Validates that a bid meets the minimum increment requirement based on price tier.

  Increment rules:
  - ₦0-₦10k → ₦100 minimum
  - ₦10k-₦50k → ₦500 minimum
  - ₦50k-₦200k → ₦1,000 minimum
  - ₦200k+ → ₦5,000 minimum
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    bid_amount = Ash.Changeset.get_attribute(changeset, :amount)
    item_id = Ash.Changeset.get_attribute(changeset, :item_id)

    # Get item with current_price
    item =
      Angle.Inventory.Item
      |> Ash.Query.filter(id == ^item_id)
      |> Ash.Query.select([:current_price, :starting_price])
      |> Ash.read_one!(authorize?: false)

    current_price = item.current_price || item.starting_price
    required_increment = calculate_increment(current_price)
    minimum_bid = Decimal.add(current_price, required_increment)

    if Decimal.compare(bid_amount, minimum_bid) == :lt do
      Ash.Changeset.add_error(
        changeset,
        field: :amount,
        message: "must be at least ₦#{format_money(required_increment)} higher than current price"
      )
    else
      changeset
    end
  end

  defp calculate_increment(price) do
    cond do
      Decimal.compare(price, Decimal.new(10_000)) == :lt -> Decimal.new(100)
      Decimal.compare(price, Decimal.new(50_000)) == :lt -> Decimal.new(500)
      Decimal.compare(price, Decimal.new(200_000)) == :lt -> Decimal.new(1_000)
      true -> Decimal.new(5_000)
    end
  end

  defp format_money(decimal) do
    decimal
    |> Decimal.to_integer()
    |> Integer.to_string()
    |> add_commas()
  end

  defp add_commas(string) do
    string
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
end
