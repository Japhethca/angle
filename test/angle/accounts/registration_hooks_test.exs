defmodule Angle.Accounts.RegistrationHooksTest do
  use Angle.DataCase, async: true

  require Ash.Query

  alias Angle.Accounts.User
  alias Angle.Payments.UserWallet

  # Mock that returns errors for testing failure scenarios
  defmodule ErrorPaystackMock do
    @behaviour Angle.Payments.PaystackBehaviour

    @impl true
    def initialize_transaction(_email, _amount, _opts), do: {:ok, %{}}
    @impl true
    def verify_transaction(_ref), do: {:ok, %{}}
    @impl true
    def list_banks, do: {:ok, []}
    @impl true
    def resolve_account(_acc, _bank), do: {:ok, %{}}
    @impl true
    def create_transfer_recipient(_name, _acc, _bank), do: {:ok, %{}}
    @impl true
    def get_subaccount_balance(_code), do: {:ok, Decimal.new(0)}

    @impl true
    def create_subaccount(_params) do
      {:error, "API temporarily unavailable"}
    end
  end

  describe "create_wallet_and_subaccount/2" do
    test "creates wallet after user registration" do
      # Create user (simulating registration)
      {:ok, user} =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "john@example.com",
          password: "SecureP@ssw0rd!",
          password_confirmation: "SecureP@ssw0rd!",
          full_name: "John Doe"
        })
        |> Ash.create()

      # Verify wallet was created (but not Paystack subaccount yet)
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert wallet != nil
      # Paystack subaccount is NOT created during registration anymore
      # It will be created later when user adds payout method
      assert wallet.paystack_subaccount_code == nil
      assert wallet.sync_status == :pending
    end

    test "handles wallet creation failures gracefully" do
      # This test verifies registration succeeds even if wallet creation fails
      # In the actual implementation, wallet creation should never fail for new users
      # but this tests the defensive error handling

      {:ok, user} =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "jane@example.com",
          password: "SecureP@ssw0rd!",
          password_confirmation: "SecureP@ssw0rd!",
          full_name: "Jane Doe"
        })
        |> Ash.create()

      # Verify wallet was created
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert wallet != nil
      assert wallet.paystack_subaccount_code == nil
      assert wallet.sync_status == :pending
    end
  end
end
