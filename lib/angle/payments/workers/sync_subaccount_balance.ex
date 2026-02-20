defmodule Angle.Payments.Workers.SyncSubaccountBalance do
  @moduledoc """
  Oban worker that syncs UserWallet balances from Paystack subaccount balances.
  Runs every 5 minutes for all wallets with subaccount codes.
  """

  use Oban.Worker,
    queue: :wallet_sync,
    max_attempts: 3

  alias Angle.Payments.UserWallet
  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"wallet_id" => wallet_id}}) do
    case Ash.get(UserWallet, wallet_id, authorize?: false) do
      {:ok, wallet} ->
        case wallet.paystack_subaccount_code do
          nil ->
            # Cancel job instead of error to prevent unnecessary retries
            {:cancel, :no_subaccount}

          subaccount_code ->
            sync_balance(wallet, subaccount_code)
        end

      {:error, %Ash.Error.Query.NotFound{}} ->
        # Wallet was deleted, cancel the job
        {:cancel, :wallet_not_found}

      {:error, error} ->
        # Other errors should be retried
        {:error, error}
    end
  end

  defp sync_balance(wallet, subaccount_code) do
    client = Application.get_env(:angle, :paystack_client, Angle.Payments.Paystack)

    case client.get_subaccount_balance(subaccount_code) do
      {:ok, balance} ->
        case wallet
             |> Ash.Changeset.for_update(:sync_balance, %{balance: balance}, authorize?: false)
             |> Ash.update() do
          {:ok, _wallet} -> :ok
          {:error, error} -> {:error, error}
        end

      {:error, reason} ->
        wallet
        |> Ash.Changeset.for_update(
          :mark_sync_error,
          %{metadata: %{last_error: reason}},
          authorize?: false
        )
        |> Ash.update()

        {:error, reason}
    end
  end
end
