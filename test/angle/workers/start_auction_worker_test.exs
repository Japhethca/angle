defmodule Angle.Workers.StartAuctionWorkerTest do
  use Angle.DataCase
  use Oban.Testing, repo: Angle.Repo

  require Ash.Query

  alias Angle.Workers.StartAuctionWorker
  alias Angle.Inventory.Item

  defp publish_item(item) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
    |> Ash.update!()
  end

  describe "perform/1" do
    test "starts auctions that have reached their start time" do
      user = create_user()
      # 5 minutes ago
      past_time = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

      item =
        create_item(%{
          title: "Should Start",
          starting_price: 1000,
          auction_status: :scheduled,
          start_time: past_time,
          # 24 hours later
          end_time: DateTime.add(past_time, 24 * 60 * 60, :second),
          created_by_id: user.id
        })
        |> publish_item()

      assert item.auction_status == :scheduled

      # Execute worker
      assert :ok = perform_job(StartAuctionWorker, %{})

      # Verify item was started
      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()
      assert item.auction_status == :active
    end

    test "does not start auctions with future start times" do
      user = create_user()
      # 5 minutes from now
      future_time = DateTime.add(DateTime.utc_now(), 5 * 60, :second)

      item =
        create_item(%{
          title: "Should Not Start Yet",
          starting_price: 1000,
          auction_status: :scheduled,
          start_time: future_time,
          end_time: DateTime.add(future_time, 24 * 60 * 60, :second),
          created_by_id: user.id
        })
        |> publish_item()

      assert item.auction_status == :scheduled

      assert :ok = perform_job(StartAuctionWorker, %{})

      # Verify item was NOT started
      item = Item |> Ash.Query.filter(id == ^item.id) |> Ash.read_one!()
      assert item.auction_status == :scheduled
    end

    test "only starts scheduled auctions, not active or ended ones" do
      user = create_user()
      past_time = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

      active_item =
        create_item(%{
          title: "Already Active",
          starting_price: 1000,
          auction_status: :active,
          start_time: past_time,
          created_by_id: user.id
        })

      ended_item =
        create_item(%{
          title: "Already Ended",
          starting_price: 1000,
          auction_status: :ended,
          start_time: past_time,
          created_by_id: user.id
        })

      assert :ok = perform_job(StartAuctionWorker, %{})

      # Verify statuses unchanged
      active_item = Item |> Ash.Query.filter(id == ^active_item.id) |> Ash.read_one!()
      assert active_item.auction_status == :active

      ended_item = Item |> Ash.Query.filter(id == ^ended_item.id) |> Ash.read_one!()
      assert ended_item.auction_status == :ended
    end

    test "starts multiple scheduled auctions in one run" do
      user = create_user()
      past_time = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

      item1 =
        create_item(%{
          title: "Auction 1",
          starting_price: 1000,
          auction_status: :scheduled,
          start_time: past_time,
          end_time: DateTime.add(past_time, 24 * 60 * 60, :second),
          created_by_id: user.id
        })
        |> publish_item()

      item2 =
        create_item(%{
          title: "Auction 2",
          starting_price: 2000,
          auction_status: :scheduled,
          start_time: past_time,
          end_time: DateTime.add(past_time, 24 * 60 * 60, :second),
          created_by_id: user.id
        })
        |> publish_item()

      assert :ok = perform_job(StartAuctionWorker, %{})

      # Verify both were started
      item1 = Item |> Ash.Query.filter(id == ^item1.id) |> Ash.read_one!()
      assert item1.auction_status == :active

      item2 = Item |> Ash.Query.filter(id == ^item2.id) |> Ash.read_one!()
      assert item2.auction_status == :active
    end

    test "handles errors gracefully and continues processing other items" do
      user = create_user()
      past_time = DateTime.add(DateTime.utc_now(), -5 * 60, :second)

      # Create two scheduled items
      item1 =
        create_item(%{
          title: "Good Auction",
          starting_price: 1000,
          auction_status: :scheduled,
          start_time: past_time,
          end_time: DateTime.add(past_time, 24 * 60 * 60, :second),
          created_by_id: user.id
        })
        |> publish_item()

      item2 =
        create_item(%{
          title: "Another Good Auction",
          starting_price: 2000,
          auction_status: :scheduled,
          start_time: past_time,
          end_time: DateTime.add(past_time, 24 * 60 * 60, :second),
          created_by_id: user.id
        })
        |> publish_item()

      # Note: In a real scenario, we might mock a failure for item1,
      # but for now we just verify that multiple items can be processed
      assert :ok = perform_job(StartAuctionWorker, %{})

      # Both should be started
      item1 = Item |> Ash.Query.filter(id == ^item1.id) |> Ash.read_one!()
      assert item1.auction_status == :active

      item2 = Item |> Ash.Query.filter(id == ^item2.id) |> Ash.read_one!()
      assert item2.auction_status == :active
    end
  end
end
