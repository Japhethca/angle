defmodule Angle.Payments.Workers.SyncSubaccountBalanceTest do
  use Angle.DataCase
  use Oban.Testing, repo: Angle.Repo

  alias Angle.Payments.Workers.SyncSubaccountBalance
  alias Angle.Payments.UserWallet

  describe "perform/1" do
    test "syncs balance from Paystack API" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user)
        |> Ash.create()

      # Set subaccount code
      {:ok, wallet} =
        wallet
        |> Ash.Changeset.for_update(:set_subaccount_code, %{
          paystack_subaccount_code: "ACCT_test123"
        })
        |> Ash.update()

      # Perform job (uses PaystackMock configured in test.exs)
      assert :ok =
               perform_job(SyncSubaccountBalance, %{"wallet_id" => wallet.id})

      # Verify wallet was updated
      updated_wallet = Ash.get!(UserWallet, wallet.id, authorize?: false)

      # PaystackMock returns 75000.50 by default
      assert Decimal.eq?(updated_wallet.balance, Decimal.new("75000.50"))
      assert updated_wallet.sync_status == :synced
      assert updated_wallet.last_synced_at != nil
    end

    test "skips wallets without subaccount code" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user)
        |> Ash.create()

      # Perform job without setting subaccount code
      assert {:error, :no_subaccount} =
               perform_job(SyncSubaccountBalance, %{"wallet_id" => wallet.id})
    end
  end
end
