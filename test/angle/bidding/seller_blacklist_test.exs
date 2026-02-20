defmodule Angle.Bidding.SellerBlacklistTest do
  use Angle.DataCase

  alias Angle.Bidding.SellerBlacklist

  require Ash.Query

  describe "create blacklist entry" do
    test "seller can blacklist a user" do
      seller = create_user()
      blocked_user = create_user()

      assert {:ok, entry} =
               SellerBlacklist
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   blocked_user_id: blocked_user.id,
                   reason: "Non-payment on previous auction"
                 },
                 actor: seller,
                 authorize?: false
               )
               |> Ash.create()

      assert entry.seller_id == seller.id
      assert entry.blocked_user_id == blocked_user.id
      assert entry.reason == "Non-payment on previous auction"
    end

    test "prevents duplicate blacklist entries" do
      seller = create_user()
      blocked_user = create_user()

      {:ok, _entry} =
        SellerBlacklist
        |> Ash.Changeset.for_create(
          :create,
          %{
            blocked_user_id: blocked_user.id,
            reason: "First reason"
          },
          actor: seller,
          authorize?: false
        )
        |> Ash.create()

      assert {:error, error} =
               SellerBlacklist
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   blocked_user_id: blocked_user.id,
                   reason: "Second reason"
                 },
                 actor: seller,
                 authorize?: false
               )
               |> Ash.create()

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message, "unique") or String.contains?(err.message, "already")
             end)
    end
  end

  describe "read blacklist" do
    test "lists all users blacklisted by a seller" do
      seller = create_user()
      user1 = create_user()
      user2 = create_user()
      user3 = create_user()

      {:ok, _} =
        SellerBlacklist
        |> Ash.Changeset.for_create(
          :create,
          %{blocked_user_id: user1.id, reason: "Reason 1"},
          actor: seller,
          authorize?: false
        )
        |> Ash.create()

      {:ok, _} =
        SellerBlacklist
        |> Ash.Changeset.for_create(
          :create,
          %{blocked_user_id: user2.id, reason: "Reason 2"},
          actor: seller,
          authorize?: false
        )
        |> Ash.create()

      blacklist =
        SellerBlacklist
        |> Ash.Query.filter(seller_id == ^seller.id)
        |> Ash.read!(authorize?: false)

      assert length(blacklist) == 2
      blocked_user_ids = Enum.map(blacklist, & &1.blocked_user_id)
      assert user1.id in blocked_user_ids
      assert user2.id in blocked_user_ids
      refute user3.id in blocked_user_ids
    end
  end

  describe "delete blacklist entry" do
    test "seller can unblock a user" do
      seller = create_user()
      blocked_user = create_user()

      {:ok, entry} =
        SellerBlacklist
        |> Ash.Changeset.for_create(
          :create,
          %{
            blocked_user_id: blocked_user.id,
            reason: "Test"
          },
          actor: seller,
          authorize?: false
        )
        |> Ash.create()

      assert :ok =
               entry
               |> Ash.Changeset.for_destroy(:destroy, %{}, authorize?: false)
               |> Ash.destroy()

      # Verify deleted
      result =
        SellerBlacklist
        |> Ash.Query.filter(id == ^entry.id)
        |> Ash.read_one(authorize?: false)

      assert result == {:ok, nil}
    end
  end
end
