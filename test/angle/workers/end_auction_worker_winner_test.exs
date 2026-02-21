defmodule Angle.Workers.EndAuctionWorkerWinnerTest do
  use Angle.DataCase
  use Oban.Testing, repo: Angle.Repo

  require Ash.Query

  alias Angle.Workers.EndAuctionWorker
  alias Angle.Inventory.Item
  alias Angle.Bidding.Bid

  defp publish_item(item) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
    |> Ash.update!()
  end

  describe "perform/1 - winner determination" do
    test "ends auction as :ended when there are no bids" do
      seller = create_user()
      past_end = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

      item =
        create_item(%{
          title: "No Bids Item",
          starting_price: 1000,
          auction_status: :active,
          start_time: DateTime.add(past_end, -24 * 60 * 60, :second),
          end_time: past_end,
          created_by_id: seller.id
        })
        |> publish_item()

      assert :ok = perform_job(EndAuctionWorker, %{})

      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()
      assert item.auction_status == :ended
    end

    test "ends auction as :sold when there are bids and no reserve price" do
      seller = create_user()
      buyer = create_verified_bidder()
      past_end = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

      item =
        create_item(%{
          title: "Has Bids No Reserve",
          starting_price: 1000,
          auction_status: :active,
          start_time: DateTime.add(past_end, -24 * 60 * 60, :second),
          end_time: past_end,
          # No reserve
          reserve_price: nil,
          created_by_id: seller.id
        })
        |> publish_item()

      # Place a bid
      {:ok, _bid} =
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

      assert :ok = perform_job(EndAuctionWorker, %{})

      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()
      assert item.auction_status == :sold
    end

    test "ends auction as :sold when highest bid meets reserve price" do
      seller = create_user()
      buyer = create_verified_bidder()
      past_end = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

      item =
        create_item(%{
          title: "Reserve Met",
          starting_price: 1000,
          reserve_price: 5000,
          auction_status: :active,
          start_time: DateTime.add(past_end, -24 * 60 * 60, :second),
          end_time: past_end,
          created_by_id: seller.id
        })
        |> publish_item()

      # Place bid that meets reserve
      {:ok, _bid} =
        Bid
        |> Ash.Changeset.for_create(
          :make_bid,
          %{
            item_id: item.id,
            amount: 5000,
            bid_type: :manual
          },
          actor: buyer
        )
        |> Ash.create(authorize?: false)

      assert :ok = perform_job(EndAuctionWorker, %{})

      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()
      assert item.auction_status == :sold
    end

    test "ends auction as :ended when highest bid does NOT meet reserve price" do
      seller = create_user()
      buyer = create_verified_bidder()
      past_end = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

      item =
        create_item(%{
          title: "Reserve Not Met",
          starting_price: 1000,
          reserve_price: 5000,
          auction_status: :active,
          start_time: DateTime.add(past_end, -24 * 60 * 60, :second),
          end_time: past_end,
          created_by_id: seller.id
        })
        |> publish_item()

      # Place bid that does NOT meet reserve
      {:ok, _bid} =
        Bid
        |> Ash.Changeset.for_create(
          :make_bid,
          %{
            item_id: item.id,
            amount: 4500,
            bid_type: :manual
          },
          actor: buyer
        )
        |> Ash.create(authorize?: false)

      assert :ok = perform_job(EndAuctionWorker, %{})

      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()
      assert item.auction_status == :ended
    end

    test "selects highest bid as winner when multiple bids exist" do
      seller = create_user()
      buyer1 = create_verified_bidder()
      buyer2 = create_verified_bidder()
      buyer3 = create_verified_bidder()
      past_end = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

      item =
        create_item(%{
          title: "Multiple Bids",
          starting_price: 1000,
          auction_status: :active,
          start_time: DateTime.add(past_end, -24 * 60 * 60, :second),
          end_time: past_end,
          created_by_id: seller.id
        })
        |> publish_item()

      # Place multiple bids
      {:ok, _bid1} =
        Bid
        |> Ash.Changeset.for_create(
          :make_bid,
          %{item_id: item.id, amount: 1100, bid_type: :manual},
          actor: buyer1
        )
        |> Ash.create(authorize?: false)

      {:ok, _bid2} =
        Bid
        |> Ash.Changeset.for_create(
          :make_bid,
          %{item_id: item.id, amount: 1600, bid_type: :manual},
          actor: buyer2
        )
        |> Ash.create(authorize?: false)

      {:ok, _bid3} =
        Bid
        |> Ash.Changeset.for_create(
          :make_bid,
          %{item_id: item.id, amount: 1200, bid_type: :manual},
          actor: buyer3
        )
        |> Ash.create(authorize?: false)

      assert :ok = perform_job(EndAuctionWorker, %{})

      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()
      assert item.auction_status == :sold

      # Verify highest bid (1600) is the winner
      # Note: We don't have a winner_bid_id field yet, but the logic should
      # use the highest bid amount to determine status
    end

    test "handles edge case of bid exactly equal to reserve price" do
      seller = create_user()
      buyer = create_verified_bidder()
      past_end = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

      item =
        create_item(%{
          title: "Bid Equals Reserve",
          starting_price: 1000,
          reserve_price: 5000,
          auction_status: :active,
          start_time: DateTime.add(past_end, -24 * 60 * 60, :second),
          end_time: past_end,
          created_by_id: seller.id
        })
        |> publish_item()

      # Place bid exactly equal to reserve
      {:ok, _bid} =
        Bid
        |> Ash.Changeset.for_create(
          :make_bid,
          %{
            item_id: item.id,
            amount: 5000,
            bid_type: :manual
          },
          actor: buyer
        )
        |> Ash.create(authorize?: false)

      assert :ok = perform_job(EndAuctionWorker, %{})

      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()
      assert item.auction_status == :sold
    end
  end
end
