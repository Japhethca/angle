defmodule Angle.Payments.UserWallet.SyncActionsTest do
  use Angle.DataCase, async: true

  require Ash.Query
  alias Angle.Payments.UserWallet

  describe "sync_balance action" do
    test "updates balance, last_synced_at, and sync_status" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      new_balance = Decimal.new("50000")

      {:ok, updated_wallet} =
        wallet
        |> Ash.Changeset.for_update(:sync_balance, %{balance: new_balance}, authorize?: false)
        |> Ash.update()

      assert Decimal.eq?(updated_wallet.balance, new_balance)
      assert updated_wallet.sync_status == :synced
      assert updated_wallet.last_synced_at != nil
      # Verify that last_synced_at was set recently (within the last 5 seconds)
      assert DateTime.diff(DateTime.utc_now(), updated_wallet.last_synced_at, :second) <= 5
    end
  end

  describe "mark_sync_error action" do
    test "marks sync_status as error and stores error details" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      error_details = %{last_error: "Connection timeout"}

      {:ok, updated_wallet} =
        wallet
        |> Ash.Changeset.for_update(:mark_sync_error, %{metadata: error_details},
          authorize?: false
        )
        |> Ash.update()

      assert updated_wallet.sync_status == :error
      assert updated_wallet.metadata["last_error"] == "Connection timeout"
    end
  end

  describe "set_subaccount_code action" do
    test "sets paystack_subaccount_code" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      subaccount_code = "ACCT_abc123xyz"

      {:ok, updated_wallet} =
        wallet
        |> Ash.Changeset.for_update(
          :set_subaccount_code,
          %{
            paystack_subaccount_code: subaccount_code
          },
          authorize?: false
        )
        |> Ash.update()

      assert updated_wallet.paystack_subaccount_code == subaccount_code
    end

    test "enforces unique constraint on subaccount_code" do
      user1 = create_user()
      user2 = create_user()

      # Wallets are automatically created by registration hook
      wallet1 =
        UserWallet
        |> Ash.Query.filter(user_id == ^user1.id)
        |> Ash.read_one!(authorize?: false)

      wallet2 =
        UserWallet
        |> Ash.Query.filter(user_id == ^user2.id)
        |> Ash.read_one!(authorize?: false)

      subaccount_code = "ACCT_duplicate"

      # First wallet gets the code
      {:ok, _} =
        wallet1
        |> Ash.Changeset.for_update(
          :set_subaccount_code,
          %{
            paystack_subaccount_code: subaccount_code
          },
          authorize?: false
        )
        |> Ash.update()

      # Second wallet should fail with duplicate constraint
      assert {:error, %Ash.Error.Invalid{}} =
               wallet2
               |> Ash.Changeset.for_update(
                 :set_subaccount_code,
                 %{
                   paystack_subaccount_code: subaccount_code
                 },
                 authorize?: false
               )
               |> Ash.update()
    end
  end
end
