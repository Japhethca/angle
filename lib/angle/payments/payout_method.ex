defmodule Angle.Payments.PayoutMethod do
  use Ash.Resource,
    otp_app: :angle,
    domain: Angle.Payments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    primary_read_warning?: false

  postgres do
    table "payout_methods"
    repo Angle.Repo
  end

  field_policies do
    field_policy [:recipient_code, :bank_code] do
      authorize_if never()
    end

    field_policy :* do
      authorize_if always()
    end
  end

  actions do
    defaults []

    create :create do
      accept [
        :bank_name,
        :bank_code,
        :account_number,
        :account_name,
        :recipient_code,
        :is_default
      ]

      argument :user_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:user_id, arg(:user_id))
    end

    read :read do
      primary? true
      filter expr(user_id == ^actor(:id))
    end

    read :list_by_user do
      filter expr(user_id == ^actor(:id))
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    default_access_type :strict

    policy action(:create) do
      authorize_if expr(^arg(:user_id) == ^actor(:id))
    end

    policy action(:read) do
      authorize_if always()
    end

    policy action(:list_by_user) do
      authorize_if always()
    end

    policy action(:destroy) do
      access_type :runtime
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :bank_name, :string, allow_nil?: false, public?: true
    attribute :bank_code, :string, allow_nil?: false, public?: true
    attribute :account_number, :string, allow_nil?: false, public?: true
    attribute :account_name, :string, allow_nil?: false, public?: true
    attribute :recipient_code, :string, allow_nil?: false, sensitive?: true, public?: true
    attribute :is_default, :boolean, default: false, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      allow_nil? false
      public? true
    end
  end
end
