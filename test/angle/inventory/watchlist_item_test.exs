defmodule Angle.Inventory.WatchlistItemTest do
  use Angle.DataCase, async: true

  describe "add to watchlist" do
    test "user can add an item to their watchlist" do
      user = create_user()
      item = create_item()

      {:ok, entry} =
        Angle.Inventory.WatchlistItem
        |> Ash.Changeset.for_create(:add, %{item_id: item.id}, actor: user)
        |> Ash.create()

      assert entry.user_id == user.id
      assert entry.item_id == item.id
    end

    test "cannot add same item twice" do
      user = create_user()
      item = create_item()

      {:ok, _} =
        Angle.Inventory.WatchlistItem
        |> Ash.Changeset.for_create(:add, %{item_id: item.id}, actor: user)
        |> Ash.create()

      assert {:error, _} =
               Angle.Inventory.WatchlistItem
               |> Ash.Changeset.for_create(:add, %{item_id: item.id}, actor: user)
               |> Ash.create()
    end
  end

  describe "remove from watchlist" do
    test "user can remove an item from their watchlist" do
      user = create_user()
      item = create_item()

      {:ok, entry} =
        Angle.Inventory.WatchlistItem
        |> Ash.Changeset.for_create(:add, %{item_id: item.id}, actor: user, authorize?: false)
        |> Ash.create()

      assert :ok =
               entry
               |> Ash.Changeset.for_destroy(:remove, %{}, actor: user)
               |> Ash.destroy()
    end
  end

  describe "watchlisted items query" do
    test "returns items in user's watchlist" do
      user = create_user()
      item1 = create_item() |> publish_item!()
      item2 = create_item() |> publish_item!()
      _item3 = create_item() |> publish_item!()

      create_watchlist_item(user: user, item: item1)
      create_watchlist_item(user: user, item: item2)

      results =
        Angle.Inventory.Item
        |> Ash.Query.for_read(:watchlisted, %{}, actor: user)
        |> Ash.read!()

      assert length(results) == 2
      ids = Enum.map(results, & &1.id)
      assert item1.id in ids
      assert item2.id in ids
    end

    test "filters by category" do
      user = create_user()
      cat1 = create_category()
      cat2 = create_category()
      item1 = create_item(%{category_id: cat1.id}) |> publish_item!()
      item2 = create_item(%{category_id: cat2.id}) |> publish_item!()

      create_watchlist_item(user: user, item: item1)
      create_watchlist_item(user: user, item: item2)

      results =
        Angle.Inventory.Item
        |> Ash.Query.for_read(:watchlisted, %{category_id: cat1.id}, actor: user)
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).id == item1.id
    end
  end

  describe "watcher_count aggregate" do
    test "counts users watching an item" do
      item = create_item()
      user1 = create_user()
      user2 = create_user()

      create_watchlist_item(user: user1, item: item)
      create_watchlist_item(user: user2, item: item)

      item = Ash.load!(item, :watcher_count, authorize?: false)
      assert item.watcher_count == 2
    end
  end

  # Helper to publish an item (changes publication_status from :draft to :published)
  defp publish_item!(item) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
    |> Ash.update!(authorize?: false)
  end
end
