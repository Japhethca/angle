defmodule Angle.Payments.Workers.SyncSubaccountBalanceTest do
  use Angle.DataCase
  use Oban.Testing, repo: Angle.Repo

  require Ash.Query
  alias Angle.Payments.Workers.SyncSubaccountBalance
  alias Angle.Payments.UserWallet

  defmodule ErrorPaystackMock do
    @behaviour Angle.Payments.PaystackBehaviour

    def initialize_transaction(_email, _amount, _opts \\ []), do: {:ok, %{}}
    def verify_transaction(_reference), do: {:ok, %{}}
    def list_banks, do: {:ok, []}
    def resolve_account(_account_number, _bank_code), do: {:ok, %{}}
    def create_transfer_recipient(_name, _account_number, _bank_code), do: {:ok, %{}}
    def create_subaccount(_params), do: {:ok, %{}}

    def get_subaccount_balance(_subaccount_code) do
      {:error, "Connection timeout"}
    end
  end

  describe "perform/1" do
    test "syncs balance from Paystack API" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

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

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      # Clear the subaccount code to test the skip logic
      {:ok, wallet} =
        wallet
        |> Ash.Changeset.for_update(:set_subaccount_code, %{paystack_subaccount_code: nil})
        |> Ash.update()

      # Perform job without subaccount code - should cancel instead of error
      assert {:cancel, :no_subaccount} =
               perform_job(SyncSubaccountBalance, %{"wallet_id" => wallet.id})
    end

    test "handles API errors gracefully" do
      # Configure error mock for this test
      original_client = Application.get_env(:angle, :paystack_client)
      Application.put_env(:angle, :paystack_client, ErrorPaystackMock)

      # Ensure cleanup happens even if test fails
      on_exit(fn ->
        Application.put_env(
          :angle,
          :paystack_client,
          original_client || Angle.Payments.PaystackMock
        )
      end)

      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      {:ok, wallet} =
        wallet
        |> Ash.Changeset.for_update(:set_subaccount_code, %{
          paystack_subaccount_code: "ACCT_test123"
        })
        |> Ash.update()

      # Perform job
      assert {:error, "Connection timeout"} =
               perform_job(SyncSubaccountBalance, %{"wallet_id" => wallet.id})

      # Verify wallet was marked with error
      updated_wallet = Ash.get!(UserWallet, wallet.id, authorize?: false)

      assert updated_wallet.sync_status == :error
      assert updated_wallet.metadata["last_error"] == "Connection timeout"
    end
  end
end
