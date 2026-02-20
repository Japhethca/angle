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
end
