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

  identities do
    identity :name_scope_key, [:name, :scope]
  end
end
