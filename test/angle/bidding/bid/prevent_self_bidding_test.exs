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

  # Helper to setup a user with wallet and verification for bidding
  defp setup_bidder(opts \\ []) do
    balance = Keyword.get(opts, :balance, 5000)
    user = create_user()
    _wallet = create_wallet(user: user, balance: balance)
    _verification = create_verification(%{user: user, phone_verified: true, id_verified: true})
    user
  end

  describe "prevent_self_bidding/2" do
    test "allows bidding on others' items" do
      seller = create_user()
      buyer = setup_bidder()

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
      seller = setup_bidder()

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
