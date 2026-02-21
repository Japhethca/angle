defmodule Angle.Payments.WalletTransaction do
  use Ash.Resource,
    otp_app: :angle,
    domain: Angle.Payments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  postgres do
    table "wallet_transactions"
    repo Angle.Repo

    custom_indexes do
      index [:wallet_id]
    end
  end

  typescript do
    type_name "WalletTransaction"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :wallet_id,
        :amount,
        :transaction_type,
        :balance_before,
        :balance_after,
        :reference,
        :metadata
      ]

      validate compare(:amount, greater_than: 0),
        message: "amount must be positive"

      change fn changeset, _context ->
        balance_before = Ash.Changeset.get_attribute(changeset, :balance_before)
        balance_after = Ash.Changeset.get_attribute(changeset, :balance_after)
        amount = Ash.Changeset.get_attribute(changeset, :amount)
        txn_type = Ash.Changeset.get_attribute(changeset, :transaction_type)

        # Skip validation if any field is nil
        if is_nil(balance_before) or is_nil(balance_after) or is_nil(amount) do
          changeset
        else
          expected_after =
            case txn_type do
              t when t in [:deposit, :sale_credit, :refund] ->
                Decimal.add(balance_before, amount)

              t when t in [:withdrawal, :purchase, :commission] ->
                Decimal.sub(balance_before, amount)

              _ ->
                balance_after
            end

          if Decimal.equal?(balance_after, expected_after) do
            changeset
          else
            Ash.Changeset.add_error(
              changeset,
              field: :balance_after,
              message:
                "balance_after must equal balance_before +/- amount (expected #{Decimal.to_string(expected_after)}, got #{Decimal.to_string(balance_after)})"
            )
          end
        end
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(exists(wallet, user_id == ^actor(:id)))
    end

    policy action_type(:create) do
      # Only system can create transactions (via wallet actions)
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :amount, :decimal do
      allow_nil? false
      public? true
      constraints precision: 15, scale: 2
    end

    attribute :transaction_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:deposit, :withdrawal, :purchase, :sale_credit, :refund, :commission]
    end

    attribute :balance_before, :decimal do
      allow_nil? false
      public? true
      constraints precision: 15, scale: 2
    end

    attribute :balance_after, :decimal do
      allow_nil? false
      public? true
      constraints precision: 15, scale: 2
    end

    attribute :reference, :string do
      allow_nil? false
      public? true
    end

    attribute :metadata, :map do
      allow_nil? true
      public? true
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :wallet, Angle.Payments.UserWallet do
      allow_nil? false
      public? true
    end
  end
end
