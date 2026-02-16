defmodule Angle.Inventory.ItemMyListingsTest do
  use Angle.DataCase, async: true

  alias Angle.Factory

  setup do
    user = Factory.create_user()
    category = Factory.create_category()

    # Create items with different statuses.
    # publication_status and auction_status are generated? true,
    # so we set them via Ecto after creation.
    active_item =
      Factory.create_item(%{created_by_id: user.id, category_id: category.id})
      |> set_statuses(:published, :active)

    scheduled_item =
      Factory.create_item(%{created_by_id: user.id, category_id: category.id})
      |> set_statuses(:published, :scheduled)

    ended_item =
      Factory.create_item(%{created_by_id: user.id, category_id: category.id})
      |> set_statuses(:published, :ended)

    sold_item =
      Factory.create_item(%{created_by_id: user.id, category_id: category.id})
      |> set_statuses(:published, :sold)

    draft_item =
      Factory.create_item(%{created_by_id: user.id, category_id: category.id})
      |> set_statuses(:draft, :pending)

    %{
      user: user,
      active_item: active_item,
      scheduled_item: scheduled_item,
      ended_item: ended_item,
      sold_item: sold_item,
      draft_item: draft_item
    }
  end

  defp set_statuses(item, pub_status, auction_status) do
    item
    |> Ecto.Changeset.change(%{
      publication_status: pub_status,
      auction_status: auction_status
    })
    |> Angle.Repo.update!()
  end

  describe "my_listings with status_filter" do
    test "returns all items when status_filter is :all", %{user: user} do
      {:ok, result} =
        Angle.Inventory.Item
        |> Ash.Query.for_read(:my_listings, %{status_filter: :all}, actor: user)
        |> Ash.read()

      assert length(result) == 5
    end

    test "defaults to :all when status_filter is not provided", %{user: user} do
      {:ok, result} =
        Angle.Inventory.Item
        |> Ash.Query.for_read(:my_listings, %{}, actor: user)
        |> Ash.read()

      assert length(result) == 5
    end

    test "returns active and scheduled items when status_filter is :active", %{
      user: user,
      active_item: active_item,
      scheduled_item: scheduled_item
    } do
      {:ok, result} =
        Angle.Inventory.Item
        |> Ash.Query.for_read(:my_listings, %{status_filter: :active}, actor: user)
        |> Ash.read()

      ids = Enum.map(result, & &1.id) |> Enum.sort()
      expected = Enum.sort([active_item.id, scheduled_item.id])
      assert ids == expected
    end

    test "returns ended and sold items when status_filter is :ended", %{
      user: user,
      ended_item: ended_item,
      sold_item: sold_item
    } do
      {:ok, result} =
        Angle.Inventory.Item
        |> Ash.Query.for_read(:my_listings, %{status_filter: :ended}, actor: user)
        |> Ash.read()

      ids = Enum.map(result, & &1.id) |> Enum.sort()
      expected = Enum.sort([ended_item.id, sold_item.id])
      assert ids == expected
    end

    test "returns only draft items when status_filter is :draft", %{
      user: user,
      draft_item: draft_item
    } do
      {:ok, result} =
        Angle.Inventory.Item
        |> Ash.Query.for_read(:my_listings, %{status_filter: :draft}, actor: user)
        |> Ash.read()

      assert length(result) == 1
      assert hd(result).id == draft_item.id
    end

    test "does not return items from other users", %{user: user} do
      other_user = Factory.create_user()

      Factory.create_item(%{created_by_id: other_user.id})
      |> set_statuses(:published, :active)

      {:ok, result} =
        Angle.Inventory.Item
        |> Ash.Query.for_read(:my_listings, %{status_filter: :all}, actor: user)
        |> Ash.read()

      # Only the 5 items from setup, not the other user's item
      assert length(result) == 5
    end
  end
end
