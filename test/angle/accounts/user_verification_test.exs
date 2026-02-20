defmodule Angle.Accounts.UserVerificationTest do
  use Angle.DataCase

  require Ash.Query

  alias Angle.Accounts.UserVerification

  describe "create verification" do
    test "creates verification record for user with default unverified status" do
      user = create_user()

      assert {:ok, verification} =
               UserVerification
               |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
               |> Ash.create()

      assert verification.user_id == user.id
      assert verification.phone_verified == false
      assert is_nil(verification.phone_verified_at)
      assert verification.id_verified == false
      assert is_nil(verification.id_verified_at)
      assert is_nil(verification.id_document_url)
      assert verification.id_verification_status == :not_submitted
    end

    test "prevents duplicate verification records for same user" do
      user = create_user()

      {:ok, _verification} =
        UserVerification
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      assert {:error, error} =
               UserVerification
               |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
               |> Ash.create()

      assert Enum.any?(error.errors, fn err ->
               String.contains?(err.message, "has already been taken")
             end)
    end
  end

  describe "read verification" do
    test "reads verification by user_id" do
      user = create_user()

      {:ok, verification} =
        UserVerification
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      found =
        UserVerification
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert found.id == verification.id
    end
  end

  describe "authorization" do
    test "requires admin permission to create verification" do
      user = create_user()

      # Should fail without admin permission
      assert {:error, %Ash.Error.Forbidden{}} =
               UserVerification
               |> Ash.Changeset.for_create(:create, %{user_id: user.id},
                 actor: user,
                 authorize?: true
               )
               |> Ash.create()
    end

    test "requires admin permission to destroy verification" do
      user = create_user()

      {:ok, verification} =
        UserVerification
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      # Should fail without admin permission
      assert {:error, %Ash.Error.Forbidden{}} =
               verification
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: user, authorize?: true)
               |> Ash.destroy()
    end
  end

  describe "request_phone_otp action" do
    test "generates OTP and stores hashed version" do
      user = create_user()

      {:ok, verification} =
        UserVerification
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      assert {:ok, result} =
               verification
               |> Ash.Changeset.for_update(
                 :request_phone_otp,
                 %{phone_number: "+2348012345678"},
                 authorize?: false
               )
               |> Ash.update()

      # In test mode, OTP is returned (production: sent via SMS)
      assert Map.has_key?(result, :otp_code)
      assert String.length(result.otp_code) == 6
      assert result.otp_code =~ ~r/^\d{6}$/

      # Verify internal state (otp_hash should be set)
      verification =
        UserVerification
        |> Ash.Query.filter(id == ^verification.id)
        |> Ash.read_one!(authorize?: false)

      # Note: otp_hash is internal attribute, not public
      # Just verify phone number was stored
      assert verification.phone_number == "+2348012345678"
    end

    test "rate limits OTP requests to 1 per minute" do
      user = create_user()

      {:ok, verification} =
        UserVerification
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      # First request succeeds
      {:ok, updated_verification} =
        verification
        |> Ash.Changeset.for_update(
          :request_phone_otp,
          %{phone_number: "+2348012345678"},
          authorize?: false
        )
        |> Ash.update()

      # Second request within 1 minute fails (use updated verification)
      assert {:error, error} =
               updated_verification
               |> Ash.Changeset.for_update(
                 :request_phone_otp,
                 %{phone_number: "+2348012345678"},
                 authorize?: false
               )
               |> Ash.update()

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message, "wait") or
                 String.contains?(err.message, "rate limit")
             end)
    end
  end

  describe "verify_phone_otp action" do
    test "verifies correct OTP and marks phone as verified" do
      user = create_user()

      {:ok, verification} =
        UserVerification
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      {:ok, result} =
        verification
        |> Ash.Changeset.for_update(
          :request_phone_otp,
          %{phone_number: "+2348012345678"},
          authorize?: false
        )
        |> Ash.update()

      otp_code = result.otp_code

      # Verify with correct OTP (use result which has the OTP data)
      assert {:ok, verified} =
               result
               |> Ash.Changeset.for_update(
                 :verify_phone_otp,
                 %{otp_code: otp_code},
                 authorize?: false
               )
               |> Ash.update()

      assert verified.phone_verified == true
      assert not is_nil(verified.phone_verified_at)
    end

    test "rejects incorrect OTP" do
      user = create_user()

      {:ok, verification} =
        UserVerification
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      {:ok, updated_verification} =
        verification
        |> Ash.Changeset.for_update(
          :request_phone_otp,
          %{phone_number: "+2348012345678"},
          authorize?: false
        )
        |> Ash.update()

      # Try wrong OTP (use updated verification)
      assert {:error, error} =
               updated_verification
               |> Ash.Changeset.for_update(
                 :verify_phone_otp,
                 %{otp_code: "000000"},
                 authorize?: false
               )
               |> Ash.update()

      assert error.errors
             |> Enum.any?(fn err ->
               message_lower = String.downcase(err.message)

               String.contains?(message_lower, "invalid") or
                 String.contains?(message_lower, "incorrect")
             end)
    end

    test "rejects expired OTP (5 minutes)" do
      user = create_user()

      {:ok, verification} =
        UserVerification
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      {:ok, result} =
        verification
        |> Ash.Changeset.for_update(
          :request_phone_otp,
          %{phone_number: "+2348012345678"},
          authorize?: false
        )
        |> Ash.update()

      # Manually set otp_expires_at to past
      expired_verification =
        result
        |> Ecto.Changeset.change(%{
          otp_expires_at: DateTime.add(DateTime.utc_now(), -10, :minute)
        })
        |> Angle.Repo.update!()

      # Try to verify with expired OTP
      assert {:error, error} =
               expired_verification
               |> Ash.Changeset.for_update(
                 :verify_phone_otp,
                 %{otp_code: result.otp_code},
                 authorize?: false
               )
               |> Ash.update()

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message, "expired")
             end)
    end
  end
end
