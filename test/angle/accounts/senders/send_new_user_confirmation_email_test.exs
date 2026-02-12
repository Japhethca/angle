defmodule Angle.Accounts.User.Senders.SendNewUserConfirmationEmailTest do
  use Angle.DataCase, async: true

  require Ash.Query

  alias Angle.Accounts.User.Senders.SendNewUserConfirmationEmail
  alias Angle.Factory

  describe "send/3" do
    test "creates an OTP and sends email" do
      user = Factory.create_user()

      # Should not raise — Swoosh local adapter returns a map
      SendNewUserConfirmationEmail.send(user, "fake_jwt_token", [])

      # Verify OTP was created with the fake token
      # (The auto-confirmation on user create also triggers a send with a real JWT)
      import Ash.Expr

      otps =
        Ash.Query.filter(
          Angle.Accounts.Otp,
          expr(user_id == ^user.id and confirmation_token == "fake_jwt_token")
        )
        |> Ash.read!(domain: Angle.Accounts, authorize?: false)

      assert length(otps) == 1
      otp = List.first(otps)
      assert otp.purpose == "confirm_new_user"
    end
  end
end
