defmodule Angle.Accounts.StoreProfileTest do
  use Angle.DataCase, async: true

  require Ash.Query

  describe "upsert action" do
    test "creates a store profile for a user" do
      user = create_user()

      profile =
        create_store_profile(%{
          user_id: user.id,
          store_name: "My Test Store",
          contact_phone: "08012345678",
          whatsapp_link: "wa.me/2348012345678",
          location: "Lagos",
          address: "9A, Bade drive, Lagos",
          delivery_preference: "seller_delivers"
        })

      assert profile.store_name == "My Test Store"
      assert profile.contact_phone == "08012345678"
      assert profile.whatsapp_link == "wa.me/2348012345678"
      assert profile.location == "Lagos"
      assert profile.address == "9A, Bade drive, Lagos"
      assert profile.delivery_preference == "seller_delivers"
      assert profile.user_id == user.id
    end

    test "upserts (updates) when store profile already exists for user" do
      user = create_user()
      _first = create_store_profile(%{user_id: user.id, store_name: "Original"})

      updated = create_store_profile(%{user_id: user.id, store_name: "Updated Name"})

      assert updated.store_name == "Updated Name"
      assert updated.user_id == user.id

      # Verify only one store profile exists for this user
      profiles =
        Angle.Accounts.StoreProfile
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read!(authorize?: false)

      assert length(profiles) == 1
    end

    test "requires store_name" do
      user = create_user()

      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(
          Angle.Accounts.StoreProfile,
          %{user_id: user.id},
          action: :upsert,
          authorize?: false
        )
      end
    end

    test "defaults delivery_preference to you_arrange" do
      user = create_user()
      profile = create_store_profile(%{user_id: user.id, store_name: "My Store"})

      assert profile.delivery_preference == "you_arrange"
    end
  end

  describe "authorization" do
    test "owner can upsert their own store profile" do
      user = create_user()

      profile =
        Ash.create!(
          Angle.Accounts.StoreProfile,
          %{user_id: user.id, store_name: "My Store"},
          action: :upsert,
          actor: user
        )

      assert profile.store_name == "My Store"
      assert profile.user_id == user.id
    end

    test "rejects upsert from a different user" do
      user = create_user()
      other_user = create_user()

      assert_raise Ash.Error.Forbidden, fn ->
        Ash.create!(
          Angle.Accounts.StoreProfile,
          %{user_id: user.id, store_name: "Hacked Store"},
          action: :upsert,
          actor: other_user
        )
      end
    end
  end
end
