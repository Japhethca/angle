defmodule Angle.Accounts.RolePermission do
  use Ash.Resource,
    domain: Angle.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "role_permissions"
    repo Angle.Repo
  end

  resource do
    require_primary_key? false
  end

  actions do
    defaults [:read, create: :*]
  end

  policies do
    # Only admins can manage role permissions
    policy action_type([:read, :create]) do
      authorize_if expr(exists(actor.user_roles, role.name == "admin"))
    end
  end

  attributes do
    attribute :role_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :permission_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :granted_at, :utc_datetime_usec do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    attribute :granted_by_id, :uuid do
      public? true
      description "ID of the user who granted this permission"
    end

    timestamps()
  end

  relationships do
    belongs_to :role, Angle.Accounts.Role do
      allow_nil? false
      public? true
      source_attribute :role_id
    end

    belongs_to :permission, Angle.Accounts.Permission do
      allow_nil? false
      public? true
      source_attribute :permission_id
    end

    belongs_to :granted_by, Angle.Accounts.User do
      public? true
      source_attribute :granted_by_id
    end
  end
end
