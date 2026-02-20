defmodule Angle.Recommendations.AuthorizationTest do
  use Angle.DataCase, async: true

  alias Angle.Recommendations.UserInterest
  alias Angle.Recommendations.ItemSimilarity
  alias Angle.Recommendations.RecommendedItem

  describe "UserInterest authorization" do
    test "users can read their own interests" do
      user = create_user()
      category = create_category()
      interest = create_interest(%{user_id: user.id, category_id: category.id})

      # Read should succeed with actor set to the owning user
      assert {:ok, fetched} = Ash.get(UserInterest, interest.id, actor: user)

      assert fetched.id == interest.id
      assert fetched.user_id == user.id
    end

    test "users cannot read other users' interests" do
      user1 = create_user()
      user2 = create_user()
      category = create_category()
      interest = create_interest(%{user_id: user1.id, category_id: category.id})

      # User2 should not be able to read user1's interests (returns NotFound for security)
      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(UserInterest, interest.id, actor: user2)
    end

    test "anonymous users cannot read interests" do
      user = create_user()
      category = create_category()
      interest = create_interest(%{user_id: user.id, category_id: category.id})

      # No actor means anonymous access (returns NotFound for security)
      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(UserInterest, interest.id)
    end

    test "users can use by_user action to fetch their interests" do
      user = create_user()
      category1 = create_category()
      category2 = create_category()

      interest1 = create_interest(%{user_id: user.id, category_id: category1.id})
      interest2 = create_interest(%{user_id: user.id, category_id: category2.id})

      # Create interest for another user
      other_user = create_user()
      _other_interest = create_interest(%{user_id: other_user.id, category_id: category1.id})

      # Fetch user's own interests
      assert {:ok, interests} =
               UserInterest
               |> Ash.Query.for_read(:by_user, %{user_id: user.id}, actor: user)
               |> Ash.read()

      interest_ids = Enum.map(interests, & &1.id)
      assert interest1.id in interest_ids
      assert interest2.id in interest_ids
      assert length(interests) == 2
    end

    test "users cannot create interests directly" do
      user = create_user()
      category = create_category()

      # Attempt to create with actor set
      assert {:error, %Ash.Error.Forbidden{}} =
               UserInterest
               |> Ash.Changeset.for_create(:create, %{
                 user_id: user.id,
                 category_id: category.id,
                 interest_score: 0.5
               })
               |> Ash.create(actor: user)
    end

    test "users cannot update interests directly" do
      user = create_user()
      category = create_category()
      interest = create_interest(%{user_id: user.id, category_id: category.id})

      # Attempt to update with actor set
      assert {:error, %Ash.Error.Forbidden{}} =
               interest
               |> Ash.Changeset.for_update(:update, %{interest_score: 0.9})
               |> Ash.update(actor: user)
    end

    test "users cannot destroy interests directly" do
      user = create_user()
      category = create_category()
      interest = create_interest(%{user_id: user.id, category_id: category.id})

      # Attempt to destroy with actor set
      assert {:error, %Ash.Error.Forbidden{}} =
               interest
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy(actor: user)
    end
  end

  describe "ItemSimilarity authorization" do
    test "anyone can read item similarities" do
      similarity = create_similarity()

      # Anonymous access should work
      assert {:ok, fetched} = Ash.get(ItemSimilarity, similarity.id)

      assert fetched.id == similarity.id
    end

    test "authenticated users can read item similarities" do
      user = create_user()
      similarity = create_similarity()

      # Authenticated user should be able to read
      assert {:ok, fetched} = Ash.get(ItemSimilarity, similarity.id, actor: user)

      assert fetched.id == similarity.id
    end

    test "anyone can use by_source_item action" do
      item = create_item()
      similarity1 = create_similarity(%{source_item_id: item.id})
      similarity2 = create_similarity(%{source_item_id: item.id})

      # Anonymous access should work
      assert {:ok, results} =
               ItemSimilarity
               |> Ash.Query.for_read(:by_source_item, %{source_item_id: item.id})
               |> Ash.read()

      similarity_ids = Enum.map(results, & &1.id)
      assert similarity1.id in similarity_ids
      assert similarity2.id in similarity_ids
    end

    test "anonymous users cannot create similarities" do
      item1 = create_item()
      item2 = create_item()

      # Attempt to create without actor
      assert {:error, %Ash.Error.Forbidden{}} =
               ItemSimilarity
               |> Ash.Changeset.for_create(:create, %{
                 source_item_id: item1.id,
                 similar_item_id: item2.id,
                 similarity_score: 0.8,
                 reason: :same_category
               })
               |> Ash.create()
    end

    test "authenticated users cannot create similarities" do
      user = create_user()
      item1 = create_item()
      item2 = create_item()

      # Attempt to create with actor set
      assert {:error, %Ash.Error.Forbidden{}} =
               ItemSimilarity
               |> Ash.Changeset.for_create(:create, %{
                 source_item_id: item1.id,
                 similar_item_id: item2.id,
                 similarity_score: 0.8,
                 reason: :same_category
               })
               |> Ash.create(actor: user)
    end
  end

  describe "RecommendedItem authorization" do
    test "users can read their own recommendations" do
      user = create_user()
      item = create_item()
      recommendation = create_recommendation(%{user_id: user.id, item_id: item.id})

      # Read should succeed with actor set to the owning user
      assert {:ok, fetched} = Ash.get(RecommendedItem, recommendation.id, actor: user)

      assert fetched.id == recommendation.id
      assert fetched.user_id == user.id
    end

    test "users cannot read other users' recommendations" do
      user1 = create_user()
      user2 = create_user()
      item = create_item()
      recommendation = create_recommendation(%{user_id: user1.id, item_id: item.id})

      # User2 should not be able to read user1's recommendations (returns NotFound for security)
      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(RecommendedItem, recommendation.id, actor: user2)
    end

    test "anonymous users cannot read recommendations" do
      user = create_user()
      item = create_item()
      recommendation = create_recommendation(%{user_id: user.id, item_id: item.id})

      # No actor means anonymous access (returns NotFound for security)
      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(RecommendedItem, recommendation.id)
    end

    test "users can use by_user action to fetch their recommendations" do
      user = create_user()
      item1 = create_item()
      item2 = create_item()

      rec1 = create_recommendation(%{user_id: user.id, item_id: item1.id, rank: 1})
      rec2 = create_recommendation(%{user_id: user.id, item_id: item2.id, rank: 2})

      # Create recommendation for another user
      other_user = create_user()
      _other_rec = create_recommendation(%{user_id: other_user.id, item_id: item1.id})

      # Fetch user's own recommendations
      assert {:ok, recommendations} =
               RecommendedItem
               |> Ash.Query.for_read(:by_user, %{user_id: user.id}, actor: user)
               |> Ash.read()

      rec_ids = Enum.map(recommendations, & &1.id)
      assert rec1.id in rec_ids
      assert rec2.id in rec_ids
      assert length(recommendations) == 2
    end

    test "users cannot create recommendations directly" do
      user = create_user()
      item = create_item()

      # Attempt to create with actor set
      assert {:error, %Ash.Error.Forbidden{}} =
               RecommendedItem
               |> Ash.Changeset.for_create(:create, %{
                 user_id: user.id,
                 item_id: item.id,
                 recommendation_score: 0.9,
                 rank: 1
               })
               |> Ash.create(actor: user)
    end

    test "users cannot update recommendations directly" do
      user = create_user()
      item = create_item()
      recommendation = create_recommendation(%{user_id: user.id, item_id: item.id})

      # Attempt to update with actor set
      assert {:error, %Ash.Error.Forbidden{}} =
               recommendation
               |> Ash.Changeset.for_update(:update, %{recommendation_score: 1.0})
               |> Ash.update(actor: user)
    end

    test "users cannot destroy recommendations directly" do
      user = create_user()
      item = create_item()
      recommendation = create_recommendation(%{user_id: user.id, item_id: item.id})

      # Attempt to destroy with actor set
      assert {:error, %Ash.Error.Forbidden{}} =
               recommendation
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy(actor: user)
    end
  end
end
