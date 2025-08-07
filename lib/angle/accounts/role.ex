defmodule Angle.Accounts.Role do
  use Ash.Resource,
    domain: Angle.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "roles"
    repo Angle.Repo

    identity_index_names name_scope_key: "roles_name_scope_key"
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id do
      public? true
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :scope, :string do
      allow_nil? false
      generated? true
      public? true
    end

    attribute :active, :boolean do
      generated? true
      public? true
    end

    create_timestamp :created_at do
      allow_nil? false
      public? true
    end

    update_timestamp :updated_at do
      allow_nil? false
      public? true
    end
  end

  relationships do
    has_many :user_roles, Angle.Accounts.UserRole do
      destination_attribute :role_id
      public? true
    end

    many_to_many :users, Angle.Accounts.User do
      through Angle.Accounts.UserRole
      destination_attribute_on_join_resource :user_id
      source_attribute_on_join_resource :role_id
      public? true
    end

    many_to_many :permissions, Angle.Accounts.Permission do
      through Angle.Accounts.RolePermission
      destination_attribute_on_join_resource :permission_id
      source_attribute_on_join_resource :role_id
      public? true
    end
  end

  identities do
    identity :name_scope_key, [:name, :scope]
  end
end
