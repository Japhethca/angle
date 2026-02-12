defmodule Angle.Accounts.UserRegistrationTest do
  use Angle.DataCase, async: true

  alias Angle.Factory

  describe "register_with_password" do
    test "creates user with full_name" do
      user = Factory.create_user(%{full_name: "Emmanuella Abubakar"})
      assert user.full_name == "Emmanuella Abubakar"
    end

    test "creates user with phone_number" do
      user = Factory.create_user(%{phone_number: "+2348012345678"})
      assert user.phone_number == "+2348012345678"
    end

    test "creates user without full_name (optional)" do
      user = Factory.create_user()
      assert is_nil(user.full_name)
    end

    test "creates user without phone_number (optional)" do
      user = Factory.create_user()
      assert is_nil(user.phone_number)
    end
  end
end
