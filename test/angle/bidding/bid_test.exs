defmodule Angle.Bidding.BidTest do
  use Angle.DataCase, async: true

  alias Angle.Bidding.Bid

  describe "make_bid bid amount validation" do
    setup do
      seller = create_user()

      item =
        create_item(%{
          created_by_id: seller.id,
          starting_price: Decimal.new("100.00"),
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second)
        })
        |> then(fn item ->
          item
          |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
          |> Ash.update!()
        end)

      bidder = create_bidder()

      %{seller: seller, item: item, bidder: bidder}
    end

    test "accepts bid equal to starting price when no current price exists", %{
      item: item,
      bidder: bidder
    } do
      assert {:ok, bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{amount: Decimal.new("100.00"), bid_type: :manual, item_id: item.id},
                 actor: bidder,
                 authorize?: false
               )
               |> Ash.create(authorize?: false)

      assert Decimal.equal?(bid.amount, Decimal.new("100.00"))
      assert bid.item_id == item.id
    end

    test "accepts bid above starting price when no current price exists", %{
      item: item,
      bidder: bidder
    } do
      assert {:ok, bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{amount: Decimal.new("150.00"), bid_type: :manual, item_id: item.id},
                 actor: bidder,
                 authorize?: false
               )
               |> Ash.create(authorize?: false)

      assert Decimal.equal?(bid.amount, Decimal.new("150.00"))
    end

    test "rejects bid below starting price when no current price exists", %{
      item: item,
      bidder: bidder
    } do
      assert {:error, %Ash.Error.Invalid{} = error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{amount: Decimal.new("50.00"), bid_type: :manual, item_id: item.id},
                 actor: bidder,
                 authorize?: false
               )
               |> Ash.create(authorize?: false)

      error_messages =
        error.errors
        |> Enum.map(& &1.message)

      assert Enum.any?(error_messages, fn msg ->
               msg =~ "must be greater than or equal to the starting price"
             end)
    end

    test "accepts bid above current price when current price exists", %{
      item: item,
      bidder: bidder
    } do
      # Set a current_price on the item to simulate existing bids
      {:ok, item} =
        item
        |> Ash.Changeset.for_update(:update, %{current_price: Decimal.new("200.00")},
          authorize?: false
        )
        |> Ash.update(authorize?: false)

      assert {:ok, bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{amount: Decimal.new("250.00"), bid_type: :manual, item_id: item.id},
                 actor: bidder,
                 authorize?: false
               )
               |> Ash.create(authorize?: false)

      assert Decimal.equal?(bid.amount, Decimal.new("250.00"))
    end

    test "rejects bid equal to current price", %{
      item: item,
      bidder: bidder
    } do
      # Set a current_price on the item
      {:ok, item} =
        item
        |> Ash.Changeset.for_update(:update, %{current_price: Decimal.new("200.00")},
          authorize?: false
        )
        |> Ash.update(authorize?: false)

      assert {:error, %Ash.Error.Invalid{} = error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{amount: Decimal.new("200.00"), bid_type: :manual, item_id: item.id},
                 actor: bidder,
                 authorize?: false
               )
               |> Ash.create(authorize?: false)

      error_messages =
        error.errors
        |> Enum.map(& &1.message)

      assert Enum.any?(error_messages, fn msg ->
               msg =~ "must be greater than the current price"
             end)
    end

    test "rejects bid below current price", %{
      item: item,
      bidder: bidder
    } do
      # Set a current_price on the item
      {:ok, item} =
        item
        |> Ash.Changeset.for_update(:update, %{current_price: Decimal.new("200.00")},
          authorize?: false
        )
        |> Ash.update(authorize?: false)

      assert {:error, %Ash.Error.Invalid{} = error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{amount: Decimal.new("150.00"), bid_type: :manual, item_id: item.id},
                 actor: bidder,
                 authorize?: false
               )
               |> Ash.create(authorize?: false)

      error_messages =
        error.errors
        |> Enum.map(& &1.message)

      assert Enum.any?(error_messages, fn msg ->
               msg =~ "must be greater than the current price"
             end)
    end

    test "includes the price threshold in error message when below starting price", %{
      item: item,
      bidder: bidder
    } do
      assert {:error, %Ash.Error.Invalid{} = error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{amount: Decimal.new("5.00"), bid_type: :manual, item_id: item.id},
                 actor: bidder,
                 authorize?: false
               )
               |> Ash.create(authorize?: false)

      error_messages =
        error.errors
        |> Enum.map(& &1.message)

      assert Enum.any?(error_messages, fn msg ->
               msg =~ "100"
             end)
    end

    test "includes the price threshold in error message when below current price", %{
      item: item,
      bidder: bidder
    } do
      {:ok, item} =
        item
        |> Ash.Changeset.for_update(:update, %{current_price: Decimal.new("300.00")},
          authorize?: false
        )
        |> Ash.update(authorize?: false)

      assert {:error, %Ash.Error.Invalid{} = error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{amount: Decimal.new("100.00"), bid_type: :manual, item_id: item.id},
                 actor: bidder,
                 authorize?: false
               )
               |> Ash.create(authorize?: false)

      error_messages =
        error.errors
        |> Enum.map(& &1.message)

      assert Enum.any?(error_messages, fn msg ->
               msg =~ "300"
             end)
    end
  end
end
