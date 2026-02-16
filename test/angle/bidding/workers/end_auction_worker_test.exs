defmodule Angle.Bidding.Workers.EndAuctionWorkerTest do
  use Angle.DataCase, async: true
  import Angle.Factory

  alias Angle.Bidding.Workers.EndAuctionWorker
  alias Angle.Bidding.Order

  describe "perform/1" do
    test "ends auction with winner and creates order" do
      seller = create_user()
      item = create_item(%{created_by_id: seller.id, starting_price: Decimal.new("100.00")})
      bidder1 = create_user()
      bidder2 = create_user()

      _bid1 = create_bid(%{user_id: bidder1.id, item_id: item.id, amount: Decimal.new("100.00")})
      _bid2 = create_bid(%{user_id: bidder2.id, item_id: item.id, amount: Decimal.new("150.00")})

      assert :ok = EndAuctionWorker.perform(%Oban.Job{args: %{"item_id" => item.id}})

      updated_item = Ash.get!(Angle.Inventory.Item, item.id, authorize?: false)
      assert updated_item.auction_status == :sold

      [order] = Ash.read!(Order, authorize?: false)
      assert order.buyer_id == bidder2.id
      assert order.seller_id == seller.id
      assert Decimal.equal?(order.amount, Decimal.new("150.00"))
      assert order.status == :payment_pending
    end

    test "ends auction without bids" do
      seller = create_user()
      item = create_item(%{created_by_id: seller.id})

      assert :ok = EndAuctionWorker.perform(%Oban.Job{args: %{"item_id" => item.id}})

      updated_item = Ash.get!(Angle.Inventory.Item, item.id, authorize?: false)
      assert updated_item.auction_status == :ended
    end

    test "is idempotent for already ended auctions" do
      seller = create_user()
      item = create_item(%{created_by_id: seller.id})

      # End it once
      EndAuctionWorker.perform(%Oban.Job{args: %{"item_id" => item.id}})

      # Running again should succeed without error
      assert :ok = EndAuctionWorker.perform(%Oban.Job{args: %{"item_id" => item.id}})
    end

    test "returns error for non-existent item" do
      fake_id = Ash.UUID.generate()

      assert {:error, _} =
               EndAuctionWorker.perform(%Oban.Job{args: %{"item_id" => fake_id}})
    end
  end
end
