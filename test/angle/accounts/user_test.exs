defmodule Angle.Accounts.UserTest do
  use Angle.DataCase, async: true

  describe "user creation and retrieval" do
    test "create_user/1 creates a user and it can be read back" do
      user = create_user(%{email: "test@example.com"})

      assert user.id
      assert user.email
      assert to_string(user.email) == "test@example.com"

      # Read the user back using Ash
      found =
        Angle.Accounts.User
        |> Ash.get!(user.id, authorize?: false)

      assert found.id == user.id
      assert to_string(found.email) == "test@example.com"
    end

    test "create_user/0 creates a user with default attributes" do
      user = create_user()

      assert user.id
      assert user.email
    end
  end

  describe "update_profile" do
    test "updates profile fields for the acting user" do
      user = create_user(%{full_name: "Original Name"})

      updated =
        user
        |> Ash.Changeset.for_update(:update_profile, %{
          full_name: "New Name",
          phone_number: "08012345678",
          location: "Lagos, Nigeria"
        })
        |> Ash.update!(actor: user)

      assert updated.full_name == "New Name"
      assert updated.phone_number == "08012345678"
      assert updated.location == "Lagos, Nigeria"
    end

    test "does not allow updating email via update_profile" do
      user = create_user(%{email: "original@example.com"})

      # Ash rejects `email` because it's not in the accept list for update_profile
      assert_raise Ash.Error.Invalid, ~r/No such input `email`/, fn ->
        user
        |> Ash.Changeset.for_update(:update_profile, %{
          full_name: "New Name",
          email: "hacked@example.com"
        })
        |> Ash.update!(actor: user)
      end

      # Verify the original email is unchanged
      reloaded = Ash.get!(Angle.Accounts.User, user.id, authorize?: false)
      assert to_string(reloaded.email) == "original@example.com"
    end

    test "rejects update_profile from a different user" do
      user = create_user()
      other_user = create_user()

      assert_raise Ash.Error.Forbidden, fn ->
        user
        |> Ash.Changeset.for_update(:update_profile, %{full_name: "Hacked"})
        |> Ash.update!(actor: other_user)
      end
    end
  end
end
