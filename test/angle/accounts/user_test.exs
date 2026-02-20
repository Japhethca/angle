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

  describe "change_password" do
    test "changes password with correct current password" do
      user = create_user(%{password: "oldpassword123", password_confirmation: "oldpassword123"})

      updated =
        user
        |> Ash.Changeset.for_update(:change_password, %{
          current_password: "oldpassword123",
          password: "newpassword456",
          password_confirmation: "newpassword456"
        })
        |> Ash.update!(actor: user)

      assert updated.id == user.id
    end

    test "rejects change with wrong current password" do
      user = create_user(%{password: "oldpassword123", password_confirmation: "oldpassword123"})

      assert_raise Ash.Error.Forbidden, fn ->
        user
        |> Ash.Changeset.for_update(:change_password, %{
          current_password: "wrongpassword",
          password: "newpassword456",
          password_confirmation: "newpassword456"
        })
        |> Ash.update!(actor: user)
      end
    end

    test "rejects change when password confirmation does not match" do
      user = create_user(%{password: "oldpassword123", password_confirmation: "oldpassword123"})

      assert_raise Ash.Error.Invalid, fn ->
        user
        |> Ash.Changeset.for_update(:change_password, %{
          current_password: "oldpassword123",
          password: "newpassword456",
          password_confirmation: "differentpassword"
        })
        |> Ash.update!(actor: user)
      end
    end

    test "rejects change from a different user" do
      user = create_user(%{password: "oldpassword123", password_confirmation: "oldpassword123"})
      other_user = create_user()

      assert_raise Ash.Error.Forbidden, fn ->
        user
        |> Ash.Changeset.for_update(:change_password, %{
          current_password: "oldpassword123",
          password: "newpassword456",
          password_confirmation: "newpassword456"
        })
        |> Ash.update!(actor: other_user)
      end
    end
  end

  describe "review aggregates" do
    test "avg_rating and review_count reflect received reviews" do
      buyer1 = create_user()
      buyer2 = create_user()
      seller = create_user()

      item1 = create_item(%{created_by_id: seller.id})
      item2 = create_item(%{created_by_id: seller.id})

      order1 = create_order(%{buyer: buyer1, seller: seller, item: item1})
      order2 = create_order(%{buyer: buyer2, seller: seller, item: item2})

      create_review(%{order: order1, buyer: buyer1, rating: 5})
      create_review(%{order: order2, buyer: buyer2, rating: 3})

      user =
        Angle.Accounts.User
        |> Ash.get!(seller.id, load: [:avg_rating, :review_count], authorize?: false)

      assert user.review_count == 2
      assert user.avg_rating == 4.0
    end

    test "seller with no reviews has zero count and nil avg" do
      seller = create_user()

      user =
        Angle.Accounts.User
        |> Ash.get!(seller.id, load: [:avg_rating, :review_count], authorize?: false)

      assert user.review_count == 0
      assert is_nil(user.avg_rating)
    end
  end

  describe "register_with_google" do
    test "creates new user when email does not exist" do
      # Create the bidder role first
      create_role(%{name: "bidder"})

      user_info = %{
        "sub" => "google_user_123",
        "email" => "newuser@gmail.com",
        "email_verified" => true,
        "name" => "New User",
        "picture" => "https://example.com/photo.jpg"
      }

      oauth_tokens = %{
        "access_token" => "ya29.access_token",
        "refresh_token" => "refresh_token_value",
        "expires_at" => DateTime.add(DateTime.utc_now(), 3600, :second)
      }

      user =
        Angle.Accounts.User
        |> Ash.Changeset.for_create(:register_with_google, %{
          user_info: user_info,
          oauth_tokens: oauth_tokens
        })
        |> Ash.create!(authorize?: false)

      assert user.id
      assert to_string(user.email) == "newuser@gmail.com"
      assert user.full_name == "New User"

      # Verify bidder role was assigned
      user_with_roles = Ash.load!(user, :roles, authorize?: false)
      role_names = Enum.map(user_with_roles.roles, & &1.name)
      assert "bidder" in role_names
    end

    test "links Google account to existing user with matching email" do
      # Create existing user with password
      existing_user = create_user(%{email: "existing@gmail.com", full_name: "Existing User"})

      user_info = %{
        "sub" => "google_user_456",
        "email" => "existing@gmail.com",
        "email_verified" => true,
        "name" => "Google Name",
        "picture" => "https://example.com/photo.jpg"
      }

      oauth_tokens = %{
        "access_token" => "ya29.another_token",
        "refresh_token" => "another_refresh_token",
        "expires_at" => DateTime.add(DateTime.utc_now(), 3600, :second)
      }

      # This should link the account, not create a new user
      result =
        Angle.Accounts.User
        |> Ash.Changeset.for_create(:register_with_google, %{
          user_info: user_info,
          oauth_tokens: oauth_tokens
        })
        |> Ash.create!(authorize?: false)

      # Should return the existing user, not create a new one
      assert result.id == existing_user.id
      assert to_string(result.email) == "existing@gmail.com"
      # Original full_name should be preserved
      assert result.full_name == "Existing User"

      # Verify only one user exists with this email
      users =
        Angle.Accounts.User
        |> Ash.read!(authorize?: false)
        |> Enum.filter(fn u -> to_string(u.email) == "existing@gmail.com" end)

      assert length(users) == 1
    end

    test "requires email in user_info" do
      user_info = %{
        "sub" => "google_user_789",
        "email_verified" => true,
        "name" => "No Email User"
        # Missing "email" field
      }

      oauth_tokens = %{
        "access_token" => "ya29.token",
        "refresh_token" => "refresh_token",
        "expires_at" => DateTime.add(DateTime.utc_now(), 3600, :second)
      }

      assert_raise Ash.Error.Invalid, ~r/email/i, fn ->
        Angle.Accounts.User
        |> Ash.Changeset.for_create(:register_with_google, %{
          user_info: user_info,
          oauth_tokens: oauth_tokens
        })
        |> Ash.create!(authorize?: false)
      end
    end
  end
end
