defmodule Angle.Bidding.Bid.PreventSelfBiddingTest do
  use Angle.DataCase

  alias Angle.Bidding.Bid
  require Ash.Query

  import Angle.Factory

  defp publish_item(item) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
    |> Ash.update!()
  end

  describe "prevent_self_bidding/2" do
    test "allows bidding on others' items" do
      seller = create_user()
      buyer = create_verified_bidder()

      item =
        create_item(%{
          title: "Test Item",
          starting_price: 1000,
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
                   amount: 1100,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)
    end

    test "prevents bidding on own items" do
      seller = create_verified_bidder()

      item =
        create_item(%{
          title: "My Item",
          starting_price: 1000,
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
                   amount: 1100,
                   bid_type: :manual
                 },
                 actor: seller
               )
               |> Ash.create(authorize?: false)

      assert error.errors
             |> Enum.any?(fn err -> err.message == "cannot bid on your own item" end)
    end
  end
end
