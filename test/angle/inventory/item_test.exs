defmodule Angle.Inventory.ItemTest do
  use Angle.DataCase, async: true

  require Ash.Query

  alias Angle.Inventory.Item

  defp publish_item(item) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
    |> Ash.update!()
  end

  describe "my_listings" do
    test "returns all items owned by the current user regardless of status" do
      seller = create_user()
      other = create_user()

      item1 = create_item(%{created_by_id: seller.id})
      _item2 = create_item(%{created_by_id: other.id})

      results =
        Angle.Inventory.Item
        |> Ash.Query.for_read(:my_listings, %{}, actor: seller)
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).id == item1.id
    end
  end

  describe "lifecycle attributes" do
    test "item has extension_count and original_end_time fields" do
      user = create_user()

      item =
        create_item(%{
          title: "Test Item",
          starting_price: 100,
          created_by_id: user.id
        })

      assert item.extension_count == 0
      assert is_nil(item.original_end_time)
    end
  end

  describe "start_auction/1" do
    test "transitions scheduled auction to active" do
      user = create_user()

      item =
        create_item(%{
          title: "Scheduled Item",
          starting_price: 1000,
          auction_status: :scheduled,
          start_time: ~U[2026-02-20 10:00:00Z],
          end_time: ~U[2026-02-21 10:00:00Z],
          created_by_id: user.id
        })
        |> publish_item()

      assert item.auction_status == :scheduled

      {:ok, started_item} =
        item
        |> Ash.Changeset.for_update(:start_auction)
        |> Ash.update()

      assert started_item.auction_status == :active
    end

    test "prevents starting already active auction" do
      user = create_user()

      item =
        create_item(%{
          title: "Active Item",
          starting_price: 1000,
          auction_status: :active,
          created_by_id: user.id
        })

      assert {:error, _} =
               item
               |> Ash.Changeset.for_update(:start_auction)
               |> Ash.update()
    end
  end

  describe "extend_auction/2" do
    test "extends end_time by 10 minutes and increments counter" do
      user = create_user()
      original_end = ~U[2026-02-20 10:00:00Z]

      item =
        create_item(%{
          title: "Active Item",
          starting_price: 1000,
          auction_status: :active,
          end_time: original_end,
          original_end_time: original_end,
          extension_count: 0,
          created_by_id: user.id
        })

      {:ok, extended_item} =
        item
        |> Ash.Changeset.for_update(:extend_auction, %{minutes: 10})
        |> Ash.update()

      expected_end = DateTime.add(original_end, 10 * 60, :second)
      assert DateTime.compare(extended_item.end_time, expected_end) == :eq
      assert extended_item.extension_count == 1
    end

    test "prevents more than 2 extensions" do
      user = create_user()

      item =
        create_item(%{
          title: "Extended Item",
          starting_price: 1000,
          auction_status: :active,
          end_time: ~U[2026-02-20 10:00:00Z],
          extension_count: 2,
          created_by_id: user.id
        })

      assert {:error, _changeset} =
               item
               |> Ash.Changeset.for_update(:extend_auction, %{minutes: 10})
               |> Ash.update()
    end

    test "only extends active auctions" do
      user = create_user()

      item =
        create_item(%{
          title: "Ended Item",
          starting_price: 1000,
          auction_status: :ended,
          end_time: ~U[2026-02-20 10:00:00Z],
          created_by_id: user.id
        })

      assert {:error, _} =
               item
               |> Ash.Changeset.for_update(:extend_auction, %{minutes: 10})
               |> Ash.update()
    end
  end
end
