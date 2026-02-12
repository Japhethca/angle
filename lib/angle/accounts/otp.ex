defmodule Angle.Accounts.Otp do
  use Ash.Resource,
    otp_app: :angle,
    domain: Angle.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "otps"
    repo Angle.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:code, :user_id, :confirmation_token, :purpose, :expires_at]
    end

    update :mark_used do
      accept []
      change set_attribute(:used_at, &DateTime.utc_now/0)
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :code, :string, allow_nil?: false, public?: true
    attribute :user_id, :uuid, allow_nil?: false, public?: true
    attribute :confirmation_token, :string, allow_nil?: false, sensitive?: true
    attribute :purpose, :string, allow_nil?: false, default: "confirm_new_user", public?: true
    attribute :expires_at, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :used_at, :utc_datetime_usec, public?: true
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      attribute_writable? true
      define_attribute? false
      source_attribute :user_id
    end
  end
end
