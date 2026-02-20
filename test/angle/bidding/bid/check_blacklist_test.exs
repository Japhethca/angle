defmodule Angle.Bidding.Bid.CheckBlacklistTest do
  use Angle.DataCase

  alias Angle.Bidding.{Bid, SellerBlacklist}

  defp publish_item(item) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
    |> Ash.update!()
  end

  describe "blacklist validation" do
    test "allows bid when user is not blacklisted" do
      seller = create_user()
      buyer = create_verified_bidder()

      item =
        create_item(%{
          title: "Item",
          starting_price: 10_000,
          current_price: 10_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:ok, _bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 11_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)
    end

    test "rejects bid when user is blacklisted by seller" do
      seller = create_user()
      buyer = create_verified_bidder()

      # Seller blacklists this buyer
      {:ok, _blacklist} =
        SellerBlacklist
        |> Ash.Changeset.for_create(
          :create,
          %{
            blocked_user_id: buyer.id,
            reason: "Previous non-payment"
          },
          actor: seller,
          authorize?: false
        )
        |> Ash.create()

      item =
        create_item(%{
          title: "Item",
          starting_price: 10_000,
          current_price: 10_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 11_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message, "not allowed") or
                 String.contains?(err.message, "blacklist")
             end)
    end

    test "allows bid from blacklisted user on different seller's item" do
      seller1 = create_user()
      seller2 = create_user()
      buyer = create_verified_bidder()

      # Seller1 blacklists buyer
      {:ok, _blacklist} =
        SellerBlacklist
        |> Ash.Changeset.for_create(
          :create,
          %{
            blocked_user_id: buyer.id,
            reason: "Test"
          },
          actor: seller1,
          authorize?: false
        )
        |> Ash.create()

      # But seller2's item should allow bid
      item =
        create_item(%{
          title: "Seller2 Item",
          starting_price: 10_000,
          current_price: 10_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller2.id
        })
        |> publish_item()

      assert {:ok, _bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 11_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)
    end
  end
end
