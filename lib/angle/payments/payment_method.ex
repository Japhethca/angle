defmodule Angle.Payments.PaymentMethod do
  use Ash.Resource,
    otp_app: :angle,
    domain: Angle.Payments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    primary_read_warning?: false

  postgres do
    table "payment_methods"
    repo Angle.Repo
  end

  field_policies do
    field_policy [:authorization_code, :paystack_reference] do
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
        :card_type,
        :last_four,
        :exp_month,
        :exp_year,
        :bank,
        :is_default
      ]

      argument :user_id, :uuid, allow_nil?: false
      argument :authorization_code, :string, allow_nil?: false, sensitive?: true
      argument :paystack_reference, :string, allow_nil?: false, sensitive?: true

      change set_attribute(:user_id, arg(:user_id))
      change set_attribute(:authorization_code, arg(:authorization_code))
      change set_attribute(:paystack_reference, arg(:paystack_reference))
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

    attribute :card_type, :string, allow_nil?: false, public?: true
    attribute :last_four, :string, allow_nil?: false, public?: true
    attribute :exp_month, :string, allow_nil?: false, public?: true
    attribute :exp_year, :string, allow_nil?: false, public?: true
    attribute :authorization_code, :string, allow_nil?: false, sensitive?: true, public?: true
    attribute :bank, :string, public?: true
    attribute :is_default, :boolean, default: false, public?: true
    attribute :paystack_reference, :string, allow_nil?: false, sensitive?: true, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_reference, [:paystack_reference]
  end
end
