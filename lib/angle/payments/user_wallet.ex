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

    update :deposit do
      require_atomic? false

      argument :amount, :decimal do
        allow_nil? false
        constraints precision: 15, scale: 2
      end

      validate compare(:amount, greater_than: 0),
        message: "amount must be positive"

      change fn changeset, _context ->
        amount = Ash.Changeset.get_argument(changeset, :amount)
        wallet = changeset.data

        # Update wallet fields
        changeset
        |> Ash.Changeset.change_attribute(:balance, Decimal.add(wallet.balance, amount))
        |> Ash.Changeset.change_attribute(
          :total_deposited,
          Decimal.add(wallet.total_deposited, amount)
        )
      end

      # Create transaction record after wallet update
      change after_action(fn changeset, wallet, _context ->
               amount = Ash.Changeset.get_argument(changeset, :amount)
               balance_before = changeset.data.balance

               Angle.Payments.WalletTransaction
               |> Ash.Changeset.for_create(:create, %{
                 wallet_id: wallet.id,
                 amount: amount,
                 transaction_type: :deposit,
                 balance_before: balance_before,
                 balance_after: wallet.balance,
                 reference: "DEP_#{Ash.UUID.generate()}"
               })
               |> Ash.create!(authorize?: false)

               {:ok, wallet}
             end)
    end

    update :withdraw do
      require_atomic? false

      argument :amount, :decimal do
        allow_nil? false
        constraints precision: 15, scale: 2
      end

      validate compare(:amount, greater_than: 0),
        message: "amount must be positive"

      # Validate sufficient balance
      validate fn changeset, _context ->
        amount = Ash.Changeset.get_argument(changeset, :amount)
        wallet = changeset.data

        if Decimal.compare(wallet.balance, amount) in [:gt, :eq] do
          :ok
        else
          {:error,
           field: :amount,
           message: "insufficient balance (available: #{wallet.balance}, requested: #{amount})"}
        end
      end

      change fn changeset, _context ->
        amount = Ash.Changeset.get_argument(changeset, :amount)
        wallet = changeset.data

        # Update wallet fields
        changeset
        |> Ash.Changeset.change_attribute(:balance, Decimal.sub(wallet.balance, amount))
        |> Ash.Changeset.change_attribute(
          :total_withdrawn,
          Decimal.add(wallet.total_withdrawn, amount)
        )
      end

      # Create transaction record after wallet update
      change after_action(fn changeset, wallet, _context ->
               amount = Ash.Changeset.get_argument(changeset, :amount)
               balance_before = changeset.data.balance

               Angle.Payments.WalletTransaction
               |> Ash.Changeset.for_create(:create, %{
                 wallet_id: wallet.id,
                 amount: amount,
                 transaction_type: :withdrawal,
                 balance_before: balance_before,
                 balance_after: wallet.balance,
                 reference: "WTH_#{Ash.UUID.generate()}"
               })
               |> Ash.create!(authorize?: false)

               {:ok, wallet}
             end)
    end

    update :check_minimum_balance do
      # Read-only validation - doesn't modify wallet
      require_atomic? false

      argument :required_amount, :decimal do
        allow_nil? false
        constraints precision: 15, scale: 2
      end

      validate fn changeset, _context ->
        required = Ash.Changeset.get_argument(changeset, :required_amount)
        wallet = changeset.data

        if Decimal.compare(wallet.balance, required) in [:gt, :eq] do
          :ok
        else
          {:error,
           field: :balance,
           message: "insufficient balance (available: #{wallet.balance}, required: #{required})"}
        end
      end
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
