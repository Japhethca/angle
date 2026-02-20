defmodule Angle.Payments.UserWallet do
  use Ash.Resource,
    otp_app: :angle,
    domain: Angle.Payments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  postgres do
    table "user_wallets"
    repo Angle.Repo
  end

  typescript do
    type_name "UserWallet"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      # Don't accept user_id from params
      change set_attribute(:user_id, actor(:id))
    end

    # TODO: Race condition - concurrent deposits/withdrawals can corrupt balance.
    # Should use atomic updates: `atomic_update :balance, expr(balance + ^arg(:amount))`
    # See: https://hexdocs.pm/ash/Ash.Resource.Change.Builtins.html#atomic_update/2
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

               create_transaction_record(wallet, :deposit, amount, balance_before)
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
      # Note: This reads from changeset.data which is correct for validation.
      # Will be refactored when atomic updates are implemented.
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

               create_transaction_record(wallet, :withdrawal, amount, balance_before)
             end)
    end

    read :check_minimum_balance do
      # Read-only validation - doesn't modify wallet
      argument :required_amount, :decimal do
        allow_nil? false
        constraints precision: 15, scale: 2
      end

      # Return error if balance is insufficient
      prepare fn query, context ->
        case Ash.Query.get_argument(query, :required_amount) do
          nil ->
            query

          required ->
            Ash.Query.after_action(query, fn _query, [wallet] ->
              if Decimal.compare(wallet.balance, required) in [:gt, :eq] do
                {:ok, [wallet]}
              else
                {:error,
                 field: :balance,
                 message:
                   "insufficient balance (available: #{wallet.balance}, required: #{required})"}
              end
            end)
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

    policy action([:deposit, :withdraw, :check_minimum_balance]) do
      authorize_if expr(user_id == ^actor(:id))
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

  # Private helper for creating transaction records
  defp create_transaction_record(wallet, transaction_type, amount, balance_before) do
    case Angle.Payments.WalletTransaction
         |> Ash.Changeset.for_create(:create, %{
           wallet_id: wallet.id,
           amount: amount,
           transaction_type: transaction_type,
           balance_before: balance_before,
           balance_after: wallet.balance,
           reference: generate_reference(transaction_type)
         })
         |> Ash.create(authorize?: false) do
      {:ok, _transaction} -> {:ok, wallet}
      {:error, error} -> {:error, error}
    end
  end

  defp generate_reference(:deposit), do: "DEP_#{Ash.UUID.generate()}"
  defp generate_reference(:withdrawal), do: "WTH_#{Ash.UUID.generate()}"
end
