defmodule Angle.Accounts.Permission do
  use Ash.Resource,
    domain: Angle.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshAdmin.Resource]

  json_api do
    type "permission"

    routes do
      base "/permissions"
      index :read
      post :create
      patch :update
      delete :destroy
    end
  end

  postgres do
    table "permissions"
    repo Angle.Repo

    identity_index_names name_resource_action: "permissions_name_resource_action_index"
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  policies do
    # Only admins can manage permissions
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if expr(exists(actor.user_roles, role.name == "admin"))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      description "Unique name for the permission (e.g., 'create_item', 'manage_users')"
    end

    attribute :resource, :string do
      allow_nil? false
      public? true
      description "The resource this permission applies to (e.g., 'item', 'user', 'bid')"
    end

    attribute :action, :string do
      allow_nil? false
      public? true
      description "The action this permission allows (e.g., 'create', 'read', 'update', 'delete')"
    end

    attribute :scope, :string do
      allow_nil? false
      default "system"
      public? true
      description "The scope of the permission (e.g., 'system', 'own', 'organization')"
    end

    attribute :description, :string do
      public? true
      description "Human-readable description of what this permission grants"
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :roles, Angle.Accounts.Role do
      through Angle.Accounts.RolePermission
      destination_attribute_on_join_resource :role_id
      source_attribute_on_join_resource :permission_id
      public? true
    end
  end

  identities do
    identity :name_resource_action, [:name, :resource, :action]
  end
end
