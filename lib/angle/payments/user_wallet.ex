defmodule Angle.Payments.UserWallet do
  use Ash.Resource,
    otp_app: :angle,
    domain: Angle.Payments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "user_wallets"
    repo Angle.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      # Don't accept user_id from params
      change set_attribute(:user_id, actor(:id))
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action_type(:create) do
      # Only system can create wallets (will be called from registration flow)
      authorize_if always()
    end

    policy action_type(:destroy) do
      # Only admins can destroy wallets
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "admin"}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :balance, :decimal do
      allow_nil? false
      public? true
      default Decimal.new("0")
      constraints precision: 15, scale: 2
    end

    attribute :total_deposited, :decimal do
      allow_nil? false
      public? true
      default Decimal.new("0")
      constraints precision: 15, scale: 2
    end

    attribute :total_withdrawn, :decimal do
      allow_nil? false
      public? true
      default Decimal.new("0")
      constraints precision: 15, scale: 2
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_user_wallet, [:user_id]
  end
end
