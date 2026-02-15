defmodule Angle.Accounts.StoreProfile do
  use Ash.Resource,
    otp_app: :angle,
    domain: Angle.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  postgres do
    table "store_profiles"
    repo Angle.Repo
  end

  typescript do
    type_name "StoreProfile"
  end

  actions do
    defaults [:read]

    create :upsert do
      description "Create or update a store profile for a user"

      accept [
        :store_name,
        :contact_phone,
        :whatsapp_link,
        :location,
        :address,
        :delivery_preference
      ]

      argument :user_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:user_id, arg(:user_id))

      upsert? true
      upsert_identity :unique_user

      upsert_fields [
        :store_name,
        :contact_phone,
        :whatsapp_link,
        :location,
        :address,
        :delivery_preference
      ]
    end
  end

  policies do
    policy action(:read) do
      authorize_if always()
    end

    policy action(:upsert) do
      authorize_if expr(^arg(:user_id) == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :store_name, :string, allow_nil?: false, public?: true
    attribute :contact_phone, :string, public?: true
    attribute :whatsapp_link, :string, public?: true
    attribute :location, :string, public?: true
    attribute :address, :string, public?: true
    attribute :delivery_preference, :string, public?: true, default: "you_arrange"

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
    identity :unique_user, [:user_id]
  end
end
