defmodule Angle.Accounts.RegistrationHooks do
  @moduledoc """
  Handles post-registration tasks like creating user wallet and Paystack subaccount.
  """

  alias Angle.Payments.UserWallet

  @doc """
  Creates a wallet and Paystack subaccount for a newly registered user.
  Called automatically after user registration.
  """
  def create_wallet_and_subaccount(_changeset, user, _context) do
    require Logger

    # Create wallet only - Paystack subaccount will be created later when user adds payout method
    # This avoids sending placeholder/invalid bank details to Paystack API
    case UserWallet
         |> Ash.Changeset.for_create(:create, %{}, actor: user, authorize?: false)
         |> Ash.create() do
      {:ok, _wallet} ->
        {:ok, user}

      {:error, reason} ->
        Logger.error("Failed to create wallet for user #{user.id}: #{inspect(reason)}")
        # Registration should still succeed even if wallet creation fails
        {:ok, user}
    end
  end

  defp create_paystack_subaccount(user) do
    # Get the configured Paystack client (defaults to real client, mock in tests)
    client = Application.get_env(:angle, :paystack_client, Angle.Payments.Paystack)

    # Use user's full name as business name
    # In production, this should use store_name from StoreProfile if available
    params = %{
      business_name: user.full_name,
      # These will be filled in later when user adds payout method
      # For now, use placeholder bank details
      settlement_bank: "999",
      # Paystack test bank
      account_number: "0000000000"
    }

    case client.create_subaccount(params) do
      {:ok, %{"subaccount_code" => code}} when is_binary(code) ->
        {:ok, code}

      {:ok, _other} ->
        {:error, "Subaccount creation succeeded but no subaccount_code was returned"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # This will be implemented in a future task
  # defp schedule_subaccount_retry(wallet_id) do
  #   # Schedule retry in 1 minute
  #   %{wallet_id: wallet_id}
  #   |> Angle.Payments.Workers.RetrySubaccountCreation.new(schedule_in: 60)
  #   |> Oban.insert()
  # end
end
