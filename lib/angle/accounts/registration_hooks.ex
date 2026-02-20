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
    # Create wallet first
    {:ok, wallet} =
      UserWallet
      |> Ash.Changeset.for_create(:create, %{}, actor: user, authorize?: false)
      |> Ash.create()

    # Attempt to create Paystack subaccount
    case create_paystack_subaccount(user) do
      {:ok, subaccount_code} ->
        # Update wallet with subaccount code
        wallet
        |> Ash.Changeset.for_update(
          :set_subaccount_code,
          %{paystack_subaccount_code: subaccount_code},
          authorize?: false
        )
        |> Ash.update()

        {:ok, user}

      {:error, reason} ->
        # Mark wallet with error, but don't fail registration
        wallet
        |> Ash.Changeset.for_update(
          :mark_sync_error,
          %{metadata: %{last_error: reason}},
          authorize?: false
        )
        |> Ash.update()

        # TODO: Schedule retry via background job (will be implemented in future task)
        # schedule_subaccount_retry(wallet.id)

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
      {:ok, %{"subaccount_code" => code}} ->
        {:ok, code}

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
