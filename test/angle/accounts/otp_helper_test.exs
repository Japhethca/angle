defmodule Angle.Accounts.OtpHelperTest do
  use Angle.DataCase, async: true

  alias Angle.Accounts.OtpHelper
  alias Angle.Factory

  describe "generate_code/0" do
    test "generates a 6-digit string" do
      code = OtpHelper.generate_code()
      assert String.length(code) == 6
      assert String.match?(code, ~r/^\d{6}$/)
    end
  end

  describe "create_otp/3" do
    test "creates an OTP record" do
      user = Factory.create_user()
      otp = OtpHelper.create_otp(user.id, "fake_token_123")

      assert otp.user_id == user.id
      assert otp.confirmation_token == "fake_token_123"
      assert otp.purpose == "confirm_new_user"
      assert String.length(otp.code) == 6
      assert is_nil(otp.used_at)
      assert DateTime.compare(otp.expires_at, DateTime.utc_now()) == :gt
    end

    test "invalidates previous codes on creation" do
      user = Factory.create_user()
      otp1 = OtpHelper.create_otp(user.id, "token_1")
      _otp2 = OtpHelper.create_otp(user.id, "token_2")

      # Reload otp1 to check it was marked as used
      reloaded =
        Ash.get!(Angle.Accounts.Otp, otp1.id, domain: Angle.Accounts, authorize?: false)

      assert not is_nil(reloaded.used_at)
    end
  end

  describe "verify_code/3" do
    test "returns {:ok, otp} for valid code" do
      user = Factory.create_user()
      otp = OtpHelper.create_otp(user.id, "valid_token")

      assert {:ok, verified} = OtpHelper.verify_code(otp.code, user.id)
      assert verified.id == otp.id
    end

    test "marks OTP as used after verification" do
      user = Factory.create_user()
      otp = OtpHelper.create_otp(user.id, "valid_token")

      {:ok, _} = OtpHelper.verify_code(otp.code, user.id)

      reloaded =
        Ash.get!(Angle.Accounts.Otp, otp.id, domain: Angle.Accounts, authorize?: false)

      assert not is_nil(reloaded.used_at)
    end

    test "returns {:error, :invalid_code} for wrong code" do
      user = Factory.create_user()
      _otp = OtpHelper.create_otp(user.id, "valid_token")

      assert {:error, :invalid_code} = OtpHelper.verify_code("000000", user.id)
    end

    test "returns {:error, :invalid_code} for already-used code" do
      user = Factory.create_user()
      otp = OtpHelper.create_otp(user.id, "valid_token")

      {:ok, _} = OtpHelper.verify_code(otp.code, user.id)
      assert {:error, :invalid_code} = OtpHelper.verify_code(otp.code, user.id)
    end

    test "returns {:error, :invalid_code} for wrong user" do
      user1 = Factory.create_user()
      user2 = Factory.create_user()
      otp = OtpHelper.create_otp(user1.id, "valid_token")

      assert {:error, :invalid_code} = OtpHelper.verify_code(otp.code, user2.id)
    end
  end
end
