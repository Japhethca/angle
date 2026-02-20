defmodule Angle.Recommendations.QueriesTest do
  use Angle.DataCase, async: true

  alias Angle.Recommendations.Queries

  describe "get_user_bids/2" do
    test "returns user's bids within time window" do
      user = create_user()
      category = create_category()
      item = create_item(%{category_id: category.id})

      recent_time = DateTime.add(DateTime.utc_now(), -5, :day)
      old_time = DateTime.add(DateTime.utc_now(), -35, :day)

      recent_bid = create_bid(%{user_id: user.id, item_id: item.id})
      old_bid = create_bid(%{user_id: user.id, item_id: item.id})

      # Update bid_time directly via Ecto since it's a timestamp field
      Angle.Repo.update_all(
        from(b in Angle.Bidding.Bid, where: b.id == ^recent_bid.id),
        set: [bid_time: recent_time]
      )

      Angle.Repo.update_all(
        from(b in Angle.Bidding.Bid, where: b.id == ^old_bid.id),
        set: [bid_time: old_time]
      )

      since = DateTime.add(DateTime.utc_now(), -30, :day)
      {:ok, bids} = Queries.get_user_bids(user.id, since)

      assert length(bids) == 1
      assert hd(bids).item.category_id == category.id
    end
  end

  describe "get_user_watchlist/2" do
    test "returns user's watchlist items within time window" do
      user = create_user()
      category = create_category()
      item = create_item(%{category_id: category.id})

      # Create recent watchlist item
      recent_watchlist = create_watchlist_item(user: user, item: item)

      # Create old watchlist item
      old_item = create_item(%{category_id: category.id})
      old_watchlist = create_watchlist_item(user: user, item: old_item)

      # Update inserted_at directly via Ecto
      recent_time = DateTime.add(DateTime.utc_now(), -5, :day)
      old_time = DateTime.add(DateTime.utc_now(), -35, :day)

      Angle.Repo.update_all(
        from(w in Angle.Inventory.WatchlistItem, where: w.id == ^recent_watchlist.id),
        set: [inserted_at: recent_time]
      )

      Angle.Repo.update_all(
        from(w in Angle.Inventory.WatchlistItem, where: w.id == ^old_watchlist.id),
        set: [inserted_at: old_time]
      )

      since = DateTime.add(DateTime.utc_now(), -30, :day)
      {:ok, watchlist} = Queries.get_user_watchlist(user.id, since)

      assert length(watchlist) == 1
      assert hd(watchlist).item.category_id == category.id
    end
  end

  describe "get_engaged_users/1" do
    test "returns union of bidders and watchers" do
      item = create_item()
      user1 = create_user()
      user2 = create_user()

      create_bid(%{user_id: user1.id, item_id: item.id})
      create_watchlist_item(user: user2, item: item)

      {:ok, engaged} = Queries.get_engaged_users(item.id)

      assert MapSet.member?(engaged, user1.id)
      assert MapSet.member?(engaged, user2.id)
      assert MapSet.size(engaged) == 2
    end
  end

  describe "get_engaged_users_batch/1" do
    test "returns engaged users for multiple items" do
      item1 = create_item()
      item2 = create_item()
      user1 = create_user()
      user2 = create_user()

      create_bid(%{user_id: user1.id, item_id: item1.id})
      create_watchlist_item(user: user2, item: item2)

      {:ok, engaged_map} = Queries.get_engaged_users_batch([item1.id, item2.id])

      assert MapSet.member?(Map.get(engaged_map, item1.id), user1.id)
      assert MapSet.member?(Map.get(engaged_map, item2.id), user2.id)
    end
  end
end
