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
    require Ash.Query

    # Check if wallet already exists (e.g., when linking Google account to existing user)
    existing_wallet =
      UserWallet
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read_one(authorize?: false)

    case existing_wallet do
      {:ok, nil} ->
        # No wallet exists, create one
        # Paystack subaccount will be created later when user adds payout method
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

      {:ok, _wallet} ->
        # Wallet already exists (e.g., Google sign-in for existing user)
        {:ok, user}

      {:error, reason} ->
        Logger.error(
          "Failed to check for existing wallet for user #{user.id}: #{inspect(reason)}"
        )

        # Continue with registration even if wallet check fails
        {:ok, user}
    end
  end
end
