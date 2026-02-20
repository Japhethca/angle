defmodule Angle.Accounts.RegistrationHooksTest do
  use Angle.DataCase, async: true

  require Ash.Query

  alias Angle.Accounts.User
  alias Angle.Payments.UserWallet

  describe "create_wallet_and_subaccount/2" do
    test "creates wallet and Paystack subaccount after user registration" do
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

      # Verify wallet was created
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert wallet != nil
      assert wallet.paystack_subaccount_code == "ACCT_mock_test"
      assert wallet.sync_status == :pending
    end

    test "handles Paystack API failures gracefully" do
      # Configure mock to return errors
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

      # Temporarily override the paystack client
      original_client = Application.get_env(:angle, :paystack_client)
      Application.put_env(:angle, :paystack_client, ErrorPaystackMock)

      try do
        {:ok, user} =
          User
          |> Ash.Changeset.for_create(:register_with_password, %{
            email: "jane@example.com",
            password: "SecureP@ssw0rd!",
            password_confirmation: "SecureP@ssw0rd!",
            full_name: "Jane Doe"
          })
          |> Ash.create()

        # Verify wallet was created but marked with error
        wallet =
          UserWallet
          |> Ash.Query.filter(user_id == ^user.id)
          |> Ash.read_one!(authorize?: false)

        assert wallet != nil
        assert wallet.paystack_subaccount_code == nil
        assert wallet.sync_status == :error
        assert wallet.metadata["last_error"] == "API temporarily unavailable"
      after
        # Restore original client
        Application.put_env(:angle, :paystack_client, original_client)
      end
    end
  end
end
