defmodule Angle.Payments.Workers.ScheduleWalletSyncs do
  @moduledoc """
  Oban worker that schedules wallet sync jobs for all wallets with Paystack subaccount codes.
  Runs via cron every 5 minutes.
  """

  use Oban.Worker,
    queue: :wallet_sync,
    max_attempts: 1

  alias Angle.Payments.UserWallet
  alias Angle.Payments.Workers.SyncSubaccountBalance
  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    # Find all wallets with subaccount codes
    wallets =
      UserWallet
      |> Ash.Query.filter(not is_nil(paystack_subaccount_code))
      |> Ash.read!(authorize?: false)

    # Enqueue individual sync jobs for each wallet
    wallets
    |> Enum.each(fn wallet ->
      %{wallet_id: wallet.id}
      |> SyncSubaccountBalance.new()
      |> Oban.insert()
    end)

    {:ok, %{wallets_scheduled: length(wallets)}}
  end
end
