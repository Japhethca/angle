defmodule Angle.Catalog.OptionSetValue do
  use Ash.Resource,
    domain: Angle.Catalog,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  json_api do
    type "option_set_value"

    routes do
      base "/option_set_values"
      index :read
      post :create
    end
  end

  graphql do
    type :option_set_value

    queries do
      get :option_set_value, :read
      list :option_set_values, :read
    end

    mutations do
      create :create_option_set_value, :create
    end
  end

  postgres do
    table "option_set_values"
    repo Angle.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :value, :string do
      allow_nil? false
      public? true
    end

    attribute :label, :string do
      allow_nil? false
      public? true
    end

    attribute :metadata, :map do
      default %{}
      public? true
    end

    attribute :sort_order, :integer do
      default 0
      public? true
    end

    attribute :is_active, :boolean do
      default true
      public? true
    end

    attribute :parent_set_id, :uuid do
      public? true
    end

    attribute :parent_value, :string do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :option_set, Angle.Catalog.OptionSet do
      allow_nil? false
      public? true
      attribute_writable? true
      source_attribute :option_set_id
      destination_attribute :id
    end
  end
end
