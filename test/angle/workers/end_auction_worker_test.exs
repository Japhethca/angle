defmodule Angle.Workers.EndAuctionWorkerTest do
  use Angle.DataCase
  use Oban.Testing, repo: Angle.Repo

  require Ash.Query

  alias Angle.Workers.EndAuctionWorker
  alias Angle.Inventory.Item

  defp publish_item(item) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
    |> Ash.update!()
  end

  describe "perform/1 - basic lifecycle" do
    test "ends auctions that have passed their end time" do
      user = create_user()
      # 5 minutes ago
      past_end = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

      item =
        create_item(%{
          title: "Should End",
          starting_price: 1000,
          auction_status: :active,
          # Started 24h ago
          start_time: DateTime.add(past_end, -24 * 60 * 60, :second),
          end_time: past_end,
          created_by_id: user.id
        })
        |> publish_item()

      assert item.auction_status == :active

      # Execute worker
      assert :ok = perform_job(EndAuctionWorker, %{})

      # Verify item was ended
      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()
      assert item.auction_status in [:ended, :sold]
    end

    test "does not end auctions with future end times" do
      user = create_user()
      # 5 minutes from now
      future_end = DateTime.add(DateTime.utc_now(), 5 * 60, :second)

      item =
        create_item(%{
          title: "Should Not End Yet",
          starting_price: 1000,
          auction_status: :active,
          start_time: DateTime.utc_now(),
          end_time: future_end,
          created_by_id: user.id
        })
        |> publish_item()

      assert item.auction_status == :active

      assert :ok = perform_job(EndAuctionWorker, %{})

      # Verify item was NOT ended
      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()
      assert item.auction_status == :active
    end

    test "only ends active auctions, not scheduled or already ended ones" do
      user = create_user()
      past_end = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

      scheduled_item =
        create_item(%{
          title: "Scheduled",
          starting_price: 1000,
          auction_status: :scheduled,
          end_time: past_end,
          created_by_id: user.id
        })

      ended_item =
        create_item(%{
          title: "Already Ended",
          starting_price: 1000,
          auction_status: :ended,
          end_time: past_end,
          created_by_id: user.id
        })

      assert :ok = perform_job(EndAuctionWorker, %{})

      # Verify statuses unchanged
      scheduled_item = Item |> Ash.Query.filter(id == ^scheduled_item.id) |> Ash.read_one!()
      assert scheduled_item.auction_status == :scheduled

      ended_item = Item |> Ash.Query.filter(id == ^ended_item.id) |> Ash.read_one!()
      assert ended_item.auction_status == :ended
    end

    test "ends multiple active auctions in one run" do
      user = create_user()
      past_end = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

      item1 =
        create_item(%{
          title: "Auction 1",
          starting_price: 1000,
          auction_status: :active,
          start_time: DateTime.add(past_end, -24 * 60 * 60, :second),
          end_time: past_end,
          created_by_id: user.id
        })
        |> publish_item()

      item2 =
        create_item(%{
          title: "Auction 2",
          starting_price: 2000,
          auction_status: :active,
          start_time: DateTime.add(past_end, -24 * 60 * 60, :second),
          end_time: past_end,
          created_by_id: user.id
        })
        |> publish_item()

      assert :ok = perform_job(EndAuctionWorker, %{})

      # Verify both were ended
      item1 = Item |> Ash.Query.filter(id == ^item1.id) |> Ash.read_one!()
      assert item1.auction_status in [:ended, :sold]

      item2 = Item |> Ash.Query.filter(id == ^item2.id) |> Ash.read_one!()
      assert item2.auction_status in [:ended, :sold]
    end
  end
end
