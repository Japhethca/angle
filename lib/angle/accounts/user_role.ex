defmodule Angle.Accounts.UserRole do
  use Ash.Resource,
    domain: Angle.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "user_roles"
    repo Angle.Repo
  end

  resource do
    require_primary_key? false
  end

  actions do
    defaults [:read, create: :*]
  end

  attributes do
    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :role_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :expires_at, :utc_datetime_usec do
      public? true
    end

    attribute :scope_type, :string do
      public? true
    end

    attribute :scope_id, :integer do
      public? true
    end

    create_timestamp :granted_at do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      allow_nil? false
      public? true
      source_attribute :user_id
    end

    belongs_to :role, Angle.Accounts.Role do
      allow_nil? false
      public? true
      source_attribute :role_id
    end

    belongs_to :granted_by, Angle.Accounts.User do
      source_attribute :granted_by_id
      public? true
    end
  end
end
