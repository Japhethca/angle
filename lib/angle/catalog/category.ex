defmodule Angle.Catalog.Category do
  use Ash.Resource,
    domain: Angle.Catalog,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshGraphql.Resource, AshJsonApi.Resource, AshTypescript.Resource]

  json_api do
    type "category"

    routes do
      base "/categories"
      index :read
      post :create
    end
  end

  graphql do
    type :category

    queries do
      get :category, :read
      list :categories, :read
    end

    mutations do
      create :create_category, :create
    end
  end

  postgres do
    table "categories"
    repo Angle.Repo

    identity_index_names name_parent: "categories_name_parent_index",
                         slug: "categories_slug_index"
  end

  typescript do
    type_name "Category"
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :top_level do
      filter expr(is_nil(parent_id))

      pagination offset?: true, required?: false
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :slug, :string do
      public? true
    end

    attribute :attribute_schema, :map do
      allow_nil? false
      default %{}
      generated? true
      public? true
    end

    attribute :form_schema, :map do
      default %{}
      allow_nil? false
      generated? true
      public? true
    end

    attribute :image_url, :string do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :category, Angle.Catalog.Category do
      source_attribute :parent_id
      public? true
    end

    has_many :categories, Angle.Catalog.Category do
      destination_attribute :parent_id
      public? true
    end
  end

  identities do
    identity :name_parent, [:name, :parent_id]
    identity :slug, [:slug]
  end
end
