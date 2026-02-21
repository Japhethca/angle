defmodule Angle.Bidding.Bid.CheckSoftCloseExtensionTest do
  use Angle.DataCase

  require Ash.Query

  import Angle.Factory

  # Helper to setup a user with wallet and verification for bidding
  defp setup_bidder(opts \\ []) do
    balance = Keyword.get(opts, :balance, 5000)
    user = create_user()
    _wallet = create_wallet(user: user, balance: balance)
    _verification = create_verification(%{user: user, phone_verified: true, id_verified: true})
    user
  end


  alias Angle.Bidding.Bid
  alias Angle.Inventory.Item

  defp publish_item(item) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
    |> Ash.update!()
  end

  describe "check_soft_close_extension/2" do
    test "extends auction when bid is within 10 minutes of end time" do
      seller = create_user()
      buyer = setup_bidder()

      # End time is 8 minutes in the future
      original_end = DateTime.add(DateTime.utc_now(), 8 * 60, :second)

      item =
        create_item(%{
          title: "Ending Soon Item",
          starting_price: 1000,
          auction_status: :active,
          end_time: original_end,
          extension_count: 0,
          created_by_id: seller.id
        })
        |> publish_item()

      # Place bid within soft close window
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

      # Reload item to check extension
      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()

      # Should extend by 10 minutes
      expected_end = DateTime.add(original_end, 10 * 60, :second)
      assert item.end_time == expected_end
      assert item.extension_count == 1
      assert item.original_end_time == original_end
    end

    test "does not extend when bid is not within soft close window" do
      seller = create_user()
      buyer = setup_bidder()

      # End time is 15 minutes in the future
      original_end = DateTime.add(DateTime.utc_now(), 15 * 60, :second)

      item =
        create_item(%{
          title: "Not Ending Soon",
          starting_price: 1000,
          auction_status: :active,
          end_time: original_end,
          extension_count: 0,
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

      # Reload item
      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()

      # Should NOT extend
      assert item.end_time == original_end
      assert item.extension_count == 0
      assert is_nil(item.original_end_time)
    end

    test "does not extend when max extensions (2) reached" do
      seller = create_user()
      buyer = setup_bidder()

      # End time is 28 minutes in the future (original 8 minutes + 2 extensions of 10 minutes each)
      original_end = DateTime.add(DateTime.utc_now(), 8 * 60, :second)
      extended_end = DateTime.add(original_end, 20 * 60, :second)

      item =
        create_item(%{
          title: "Already Extended Twice",
          starting_price: 1000,
          auction_status: :active,
          # Already extended
          end_time: extended_end,
          original_end_time: original_end,
          # Max reached
          extension_count: 2,
          created_by_id: seller.id
        })
        |> publish_item()

      current_end = item.end_time

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

      # Reload item
      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()

      # Should NOT extend further
      assert item.end_time == current_end
      assert item.extension_count == 2
    end

    test "only extends active auctions, not scheduled" do
      seller = create_user()
      buyer = setup_bidder()

      # End time is 8 minutes in the future
      original_end = DateTime.add(DateTime.utc_now(), 8 * 60, :second)

      item =
        create_item(%{
          title: "Scheduled Item",
          starting_price: 1000,
          # Not active yet
          auction_status: :scheduled,
          end_time: original_end,
          extension_count: 0,
          created_by_id: seller.id
        })
        |> publish_item()

      # AuctionMustBeActive allows bids on scheduled auctions
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

      # Reload item
      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()

      # Should NOT extend (not active)
      assert item.end_time == original_end
      assert item.extension_count == 0
    end
  end
end
