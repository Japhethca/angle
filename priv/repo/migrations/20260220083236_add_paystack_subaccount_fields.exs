defmodule Angle.Repo.Migrations.AddPaystackSubaccountFields do
  use Ecto.Migration

  def change do
    alter table(:user_wallets) do
      add :paystack_subaccount_code, :string
      add :last_synced_at, :utc_datetime
      add :sync_status, :string, default: "pending", null: false
      add :metadata, :map, default: %{}
    end

    create index(:user_wallets, [:sync_status, :last_synced_at])

    create unique_index(:user_wallets, [:paystack_subaccount_code],
             where: "paystack_subaccount_code IS NOT NULL"
           )
  end
end
