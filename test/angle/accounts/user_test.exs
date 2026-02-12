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
end
