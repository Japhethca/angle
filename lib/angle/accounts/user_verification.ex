defmodule Angle.Accounts.UserVerification do
  use Ash.Resource,
    domain: Angle.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "user_verifications"
    repo Angle.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:user_id]
    end
  end

  policies do
    policy action_type(:read) do
      # Users can read their own verification
      authorize_if expr(user_id == ^actor(:id))

      # Admins can read all verifications
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "admin"}
    end

    policy action_type([:create, :update, :destroy]) do
      # Only admins can modify verification records
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "admin"}
    end
  end

  attributes do
    uuid_primary_key :id

    # Phone verification
    attribute :phone_verified, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :phone_verified_at, :utc_datetime_usec do
      public? true
    end

    # ID verification
    attribute :id_verified, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :id_document_url, :string do
      public? true
    end

    attribute :id_verified_at, :utc_datetime_usec do
      public? true
    end

    attribute :id_verification_status, :atom do
      allow_nil? false
      public? true
      default :not_submitted
      constraints one_of: [:not_submitted, :pending, :approved, :rejected]
    end

    attribute :id_rejection_reason, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      allow_nil? false
      public? true
      attribute_writable? true
      # TODO: Add ON DELETE CASCADE to foreign key constraint in a future migration
      # to prevent orphaned verification records when a user is deleted
    end
  end

  identities do
    identity :unique_user_verification, [:user_id]
  end
end
