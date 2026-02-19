defmodule Angle.Bidding.Bid.ValidateBidIncrementTest do
  use Angle.DataCase

  alias Angle.Bidding.Bid
  require Ash.Query

  defp publish_item(item) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
    |> Ash.update!()
  end

  describe "validate_bid_increment/2" do
    test "validates ₦100 increment for items <₦10k" do
      seller = create_user()
      buyer = create_user()

      item =
        create_item(%{
          title: "Low value item",
          starting_price: 5000,
          current_price: 5000,
          auction_status: :active,
          created_by_id: seller.id
        })
        |> publish_item()

      # Valid: 5000 + 100 = 5100
      assert {:ok, _bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 5100,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      # Invalid: 5000 + 50 = 5050
      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 5050,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors
             |> Enum.any?(fn err ->
               err.message == "must be at least ₦100 higher than current price"
             end)
    end

    test "validates ₦500 increment for items ₦10k-₦50k" do
      seller = create_user()
      buyer = create_user()

      item =
        create_item(%{
          title: "Mid value item",
          starting_price: 20000,
          current_price: 20000,
          auction_status: :active,
          created_by_id: seller.id
        })
        |> publish_item()

      # Valid: 20000 + 500 = 20500
      assert {:ok, _bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 20500,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      # Invalid: 20000 + 200 = 20200
      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 20200,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors
             |> Enum.any?(fn err ->
               err.message == "must be at least ₦500 higher than current price"
             end)
    end

    test "validates ₦1,000 increment for items ₦50k-₦200k" do
      seller = create_user()
      buyer = create_user()

      item =
        create_item(%{
          title: "High value item",
          starting_price: 100_000,
          current_price: 100_000,
          auction_status: :active,
          created_by_id: seller.id
        })
        |> publish_item()

      # Valid: 100000 + 1000 = 101000
      assert {:ok, _bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 101_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      # Invalid: 100000 + 500 = 100500
      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 100_500,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors
             |> Enum.any?(fn err ->
               err.message == "must be at least ₦1,000 higher than current price"
             end)
    end

    test "validates ₦5,000 increment for items ≥₦200k" do
      seller = create_user()
      buyer = create_user()

      item =
        create_item(%{
          title: "Premium item",
          starting_price: 250_000,
          current_price: 250_000,
          auction_status: :active,
          created_by_id: seller.id
        })
        |> publish_item()

      # Valid: 250000 + 5000 = 255000
      assert {:ok, _bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 255_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      # Invalid: 250000 + 1000 = 251000
      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 251_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors
             |> Enum.any?(fn err ->
               err.message == "must be at least ₦5,000 higher than current price"
             end)
    end
  end
end
