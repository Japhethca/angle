defmodule Angle.Recommendations.Scoring.InterestScorerTest do
  use Angle.DataCase, async: true

  alias Angle.Recommendations.Scoring.InterestScorer

  describe "compute_user_interests/1" do
    test "returns empty list for user with no interaction history" do
      user = create_user()

      assert {:ok, []} = InterestScorer.compute_user_interests(user.id)
    end

    test "computes scores for single category with bids only" do
      user = create_user()
      category = create_category()
      item = create_item(%{category_id: category.id})

      # Create a recent bid (within 7 days, should get 1.0x multiplier)
      create_bid(%{
        user_id: user.id,
        item_id: item.id,
        amount: Decimal.new("20.00")
      })

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert length(scores) == 1

      [{category_id, score, count, last_interaction}] = scores

      assert category_id == category.id
      # Single recent bid: 3.0 * 1.0 = 3.0, normalized to 1.0
      assert_in_delta score, 1.0, 0.01
      assert count == 1
      assert %DateTime{} = last_interaction
    end

    test "computes scores for single category with watchlist items only" do
      user = create_user()
      category = create_category()
      item = create_item(%{category_id: category.id})

      # Create a watchlist item
      create_watchlist_item(user: user, item: item)

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert length(scores) == 1

      [{category_id, score, count, _last_interaction}] = scores

      assert category_id == category.id
      # Single recent watchlist: 2.0 * 1.0 = 2.0, normalized to 1.0
      assert_in_delta score, 1.0, 0.01
      assert count == 1
    end

    test "bids score higher than watchlist items for same recency" do
      user = create_user()
      category1 = create_category()
      category2 = create_category()
      item1 = create_item(%{category_id: category1.id})
      item2 = create_item(%{category_id: category2.id})

      # Create one bid and one watchlist item at roughly same time
      create_bid(%{user_id: user.id, item_id: item1.id})
      create_watchlist_item(user: user, item: item2)

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert length(scores) == 2

      # Find scores by category
      bid_score = Enum.find(scores, fn {cat_id, _, _, _} -> cat_id == category1.id end)
      watchlist_score = Enum.find(scores, fn {cat_id, _, _, _} -> cat_id == category2.id end)

      {_, bid_value, _, _} = bid_score
      {_, watchlist_value, _, _} = watchlist_score

      # Bid should score higher (3.0 vs 2.0 before normalization)
      # After normalization, bid = 1.0, watchlist = 2.0/3.0 ≈ 0.67
      assert_in_delta bid_value, 1.0, 0.01
      assert_in_delta watchlist_value, 0.67, 0.01
    end

    test "applies time decay correctly for recent interactions (7 days)" do
      user = create_user()
      category = create_category()
      item = create_item(%{category_id: category.id})

      # Create bid 5 days ago (should get 1.0x multiplier)
      five_days_ago = DateTime.utc_now() |> DateTime.add(-5, :day)

      bid =
        create_bid(%{
          user_id: user.id,
          item_id: item.id,
          amount: Decimal.new("20.00")
        })

      # Update bid_time to 5 days ago
      bid
      |> Ecto.Changeset.change(%{bid_time: five_days_ago})
      |> Angle.Repo.update!()

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert length(scores) == 1

      [{_category_id, score, _count, _last_interaction}] = scores

      # 3.0 * 1.0 = 3.0, normalized to 1.0
      assert_in_delta score, 1.0, 0.01
    end

    test "applies time decay correctly for medium-age interactions (8-30 days)" do
      user = create_user()
      category = create_category()
      item = create_item(%{category_id: category.id})

      # Create bid 15 days ago (should get 0.7x multiplier)
      fifteen_days_ago = DateTime.utc_now() |> DateTime.add(-15, :day)

      bid =
        create_bid(%{
          user_id: user.id,
          item_id: item.id,
          amount: Decimal.new("20.00")
        })

      bid
      |> Ecto.Changeset.change(%{bid_time: fifteen_days_ago})
      |> Angle.Repo.update!()

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert length(scores) == 1

      [{_category_id, score, _count, _last_interaction}] = scores

      # 3.0 * 0.7 = 2.1, normalized to 1.0
      assert_in_delta score, 1.0, 0.01
    end

    test "applies time decay correctly for older interactions (31-90 days)" do
      user = create_user()
      category = create_category()
      item = create_item(%{category_id: category.id})

      # Create bid 60 days ago (should get 0.4x multiplier)
      sixty_days_ago = DateTime.utc_now() |> DateTime.add(-60, :day)

      bid =
        create_bid(%{
          user_id: user.id,
          item_id: item.id,
          amount: Decimal.new("20.00")
        })

      bid
      |> Ecto.Changeset.change(%{bid_time: sixty_days_ago})
      |> Angle.Repo.update!()

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert length(scores) == 1

      [{_category_id, score, _count, _last_interaction}] = scores

      # 3.0 * 0.4 = 1.2, normalized to 1.0
      assert_in_delta score, 1.0, 0.01
    end

    test "applies minimal decay for very old interactions (90+ days)" do
      user = create_user()
      category = create_category()
      item = create_item(%{category_id: category.id})

      # Create bid 95 days ago (should get 0.1x multiplier)
      # Need to pass custom since parameter to include this old interaction
      old_date = DateTime.utc_now() |> DateTime.add(-95, :day)

      bid =
        create_bid(%{
          user_id: user.id,
          item_id: item.id,
          amount: Decimal.new("20.00")
        })

      bid
      |> Ecto.Changeset.change(%{bid_time: old_date})
      |> Angle.Repo.update!()

      # Pass since parameter to include interactions beyond default 90 days
      since = DateTime.utc_now() |> DateTime.add(-120, :day)
      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id, since)
      assert length(scores) == 1

      [{_category_id, score, _count, _last_interaction}] = scores

      # 3.0 * 0.1 = 0.3, normalized to 1.0
      assert_in_delta score, 1.0, 0.01
    end

    test "compares time decay across different age ranges" do
      user = create_user()
      category1 = create_category()
      category2 = create_category()
      category3 = create_category()
      item1 = create_item(%{category_id: category1.id})
      item2 = create_item(%{category_id: category2.id})
      item3 = create_item(%{category_id: category3.id})

      # Recent bid (1.0x multiplier)
      create_bid(%{user_id: user.id, item_id: item1.id})

      # 15-day old bid (0.7x multiplier)
      fifteen_days_ago = DateTime.utc_now() |> DateTime.add(-15, :day)

      bid2 = create_bid(%{user_id: user.id, item_id: item2.id})

      bid2
      |> Ecto.Changeset.change(%{bid_time: fifteen_days_ago})
      |> Angle.Repo.update!()

      # 60-day old bid (0.4x multiplier)
      sixty_days_ago = DateTime.utc_now() |> DateTime.add(-60, :day)

      bid3 = create_bid(%{user_id: user.id, item_id: item3.id})

      bid3
      |> Ecto.Changeset.change(%{bid_time: sixty_days_ago})
      |> Angle.Repo.update!()

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert length(scores) == 3

      # Find scores by category
      recent = Enum.find(scores, fn {cat_id, _, _, _} -> cat_id == category1.id end)
      medium = Enum.find(scores, fn {cat_id, _, _, _} -> cat_id == category2.id end)
      old = Enum.find(scores, fn {cat_id, _, _, _} -> cat_id == category3.id end)

      {_, recent_score, _, _} = recent
      {_, medium_score, _, _} = medium
      {_, old_score, _, _} = old

      # Recent: 3.0 * 1.0 = 3.0 → normalized to 1.0
      # Medium: 3.0 * 0.7 = 2.1 → normalized to 2.1/3.0 = 0.7
      # Old: 3.0 * 0.4 = 1.2 → normalized to 1.2/3.0 = 0.4
      assert_in_delta recent_score, 1.0, 0.01
      assert_in_delta medium_score, 0.7, 0.01
      assert_in_delta old_score, 0.4, 0.01

      # Verify ordering: recent > medium > old
      assert recent_score > medium_score
      assert medium_score > old_score
    end

    test "combines bids and watchlist items for same category" do
      user = create_user()
      category = create_category()
      item1 = create_item(%{category_id: category.id})
      item2 = create_item(%{category_id: category.id})

      # Create both bid and watchlist for same category
      create_bid(%{user_id: user.id, item_id: item1.id})
      create_watchlist_item(user: user, item: item2)

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert length(scores) == 1

      [{category_id, score, count, _last_interaction}] = scores

      assert category_id == category.id
      assert count == 2
      # Score: (3.0 * 1.0) + (2.0 * 1.0) = 5.0, normalized to 1.0
      assert_in_delta score, 1.0, 0.01
    end

    test "handles multiple categories correctly" do
      user = create_user()
      category1 = create_category()
      category2 = create_category()
      category3 = create_category()

      item1 = create_item(%{category_id: category1.id})
      item2 = create_item(%{category_id: category2.id})
      item3 = create_item(%{category_id: category3.id})

      # Different interactions for different categories
      create_bid(%{user_id: user.id, item_id: item1.id})
      create_bid(%{user_id: user.id, item_id: item1.id})
      create_watchlist_item(user: user, item: item2)
      create_bid(%{user_id: user.id, item_id: item3.id})

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert length(scores) == 3

      # Verify all categories are present
      category_ids = Enum.map(scores, fn {cat_id, _, _, _} -> cat_id end)
      assert category1.id in category_ids
      assert category2.id in category_ids
      assert category3.id in category_ids
    end

    test "normalizes scores to 0.0-1.0 range" do
      user = create_user()
      category1 = create_category()
      category2 = create_category()

      # Category 1: 3 bids (high score)
      item1 = create_item(%{category_id: category1.id})
      create_bid(%{user_id: user.id, item_id: item1.id})
      create_bid(%{user_id: user.id, item_id: item1.id})
      create_bid(%{user_id: user.id, item_id: item1.id})

      # Category 2: 1 watchlist item (lower score)
      item2 = create_item(%{category_id: category2.id})
      create_watchlist_item(user: user, item: item2)

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert length(scores) == 2

      # All scores should be between 0.0 and 1.0
      Enum.each(scores, fn {_cat_id, score, _count, _last} ->
        assert score >= 0.0
        assert score <= 1.0
      end)

      # Highest score should be 1.0
      max_score = scores |> Enum.map(fn {_, score, _, _} -> score end) |> Enum.max()
      assert_in_delta max_score, 1.0, 0.01
    end

    test "returns 4-element tuples with correct structure" do
      user = create_user()
      category = create_category()
      item = create_item(%{category_id: category.id})

      create_bid(%{user_id: user.id, item_id: item.id})

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert length(scores) == 1

      [{category_id, score, count, last_interaction}] = scores

      # Verify types
      assert is_binary(category_id)
      assert is_float(score)
      assert is_integer(count)
      assert %DateTime{} = last_interaction
    end

    test "tracks last interaction time correctly" do
      user = create_user()
      category = create_category()
      item1 = create_item(%{category_id: category.id})
      item2 = create_item(%{category_id: category.id})

      # Create older bid
      ten_days_ago = DateTime.utc_now() |> DateTime.add(-10, :day)

      bid1 = create_bid(%{user_id: user.id, item_id: item1.id})

      bid1
      |> Ecto.Changeset.change(%{bid_time: ten_days_ago})
      |> Angle.Repo.update!()

      # Create recent watchlist item
      create_watchlist_item(user: user, item: item2)

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      [{_cat_id, _score, _count, last_interaction}] = scores

      # Last interaction should be recent (watchlist), not old bid
      now = DateTime.utc_now()
      diff_seconds = DateTime.diff(now, last_interaction, :second)

      # Should be within last few seconds (recent watchlist)
      assert diff_seconds < 10
    end

    test "ignores items without categories" do
      user = create_user()

      # Create item without category
      item_no_cat = create_item(%{category_id: nil})
      create_bid(%{user_id: user.id, item_id: item_no_cat.id})

      # Create item with category
      category = create_category()
      item_with_cat = create_item(%{category_id: category.id})
      create_bid(%{user_id: user.id, item_id: item_with_cat.id})

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)

      # Should only have 1 category (the one with category_id)
      assert length(scores) == 1
      [{category_id, _, _, _}] = scores
      assert category_id == category.id
    end

    test "respects since parameter to filter old interactions" do
      user = create_user()
      category = create_category()
      item = create_item(%{category_id: category.id})

      # Create very old bid (100 days ago)
      old_date = DateTime.utc_now() |> DateTime.add(-100, :day)

      bid = create_bid(%{user_id: user.id, item_id: item.id})

      bid
      |> Ecto.Changeset.change(%{bid_time: old_date})
      |> Angle.Repo.update!()

      # Query with default (90 days) - should not include the bid
      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert scores == []

      # Query with 120 days - should include the bid
      since = DateTime.utc_now() |> DateTime.add(-120, :day)
      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id, since)
      assert length(scores) == 1
    end

    test "handles multiple bids on same item in same category" do
      user = create_user()
      category = create_category()
      item = create_item(%{category_id: category.id})

      # Create multiple bids on same item
      create_bid(%{user_id: user.id, item_id: item.id, amount: Decimal.new("10.00")})
      create_bid(%{user_id: user.id, item_id: item.id, amount: Decimal.new("15.00")})
      create_bid(%{user_id: user.id, item_id: item.id, amount: Decimal.new("20.00")})

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert length(scores) == 1

      [{_category_id, score, count, _last_interaction}] = scores

      assert count == 3
      # 3 bids * 3.0 * 1.0 = 9.0, normalized to 1.0
      assert_in_delta score, 1.0, 0.01
    end

    test "complex scenario with mixed interactions across multiple categories" do
      user = create_user()

      # Electronics category - high interest (recent + multiple)
      electronics = create_category(%{name: "Electronics"})
      laptop = create_item(%{category_id: electronics.id, title: "Laptop"})
      phone = create_item(%{category_id: electronics.id, title: "Phone"})
      create_bid(%{user_id: user.id, item_id: laptop.id})
      create_bid(%{user_id: user.id, item_id: phone.id})
      create_watchlist_item(user: user, item: laptop)

      # Books category - medium interest (older)
      books = create_category(%{name: "Books"})
      book = create_item(%{category_id: books.id, title: "Book"})
      thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

      bid_book = create_bid(%{user_id: user.id, item_id: book.id})

      bid_book
      |> Ecto.Changeset.change(%{bid_time: thirty_days_ago})
      |> Angle.Repo.update!()

      # Furniture category - low interest (old but within 90 days)
      furniture = create_category(%{name: "Furniture"})
      chair = create_item(%{category_id: furniture.id, title: "Chair"})
      # Use 70 days to ensure it's within the default 90-day window
      seventy_days_ago = DateTime.utc_now() |> DateTime.add(-70, :day)

      bid_chair = create_bid(%{user_id: user.id, item_id: chair.id})

      bid_chair
      |> Ecto.Changeset.change(%{bid_time: seventy_days_ago})
      |> Angle.Repo.update!()

      assert {:ok, scores} = InterestScorer.compute_user_interests(user.id)
      assert length(scores) == 3

      # Find each category score
      electronics_score =
        Enum.find(scores, fn {cat_id, _, _, _} -> cat_id == electronics.id end)

      books_score = Enum.find(scores, fn {cat_id, _, _, _} -> cat_id == books.id end)

      furniture_score =
        Enum.find(scores, fn {cat_id, _, _, _} -> cat_id == furniture.id end)

      {_, elec_value, elec_count, _} = electronics_score
      {_, book_value, book_count, _} = books_score
      {_, furn_value, furn_count, _} = furniture_score

      # Electronics should have highest score (multiple recent interactions)
      assert_in_delta elec_value, 1.0, 0.01
      assert elec_count == 3

      # Books should be medium
      assert book_value < elec_value
      assert book_count == 1

      # Furniture should be lowest
      assert furn_value < book_value
      assert furn_count == 1

      # Verify ordering
      assert elec_value > book_value
      assert book_value > furn_value
    end
  end
end
