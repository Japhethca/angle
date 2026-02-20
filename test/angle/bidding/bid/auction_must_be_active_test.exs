defmodule Angle.Bidding.Bid.AuctionMustBeActiveTest do
  use Angle.DataCase

  alias Angle.Bidding.Bid

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

  describe "auction_must_be_active/2" do
    test "allows bids on active auctions" do
      seller = create_user()
      buyer = setup_bidder()

      item =
        create_item(%{
          title: "Active Auction",
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

    test "allows bids on scheduled auctions" do
      seller = create_user()
      buyer = setup_bidder()

      item =
        create_item(%{
          title: "Scheduled Auction",
          starting_price: 1000,
          auction_status: :scheduled,
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

    test "prevents bids on ended auctions" do
      seller = create_user()
      buyer = setup_bidder()

      item =
        create_item(%{
          title: "Ended Auction",
          starting_price: 1000,
          auction_status: :ended,
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
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors |> Enum.any?(fn err -> err.message == "auction has ended" end)
    end

    test "prevents bids on sold auctions" do
      seller = create_user()
      buyer = setup_bidder()

      item =
        create_item(%{
          title: "Sold Auction",
          starting_price: 1000,
          auction_status: :sold,
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
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors |> Enum.any?(fn err -> err.message == "auction has ended" end)
    end

    test "prevents bids on draft items" do
      seller = create_user()
      buyer = setup_bidder()

      item =
        create_item(%{
          title: "Draft Item",
          starting_price: 1000,
          publication_status: :draft,
          created_by_id: seller.id
        })

      assert {:error, error} =
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

      assert error.errors |> Enum.any?(fn err -> err.message == "auction is not active" end)
    end
  end
end
