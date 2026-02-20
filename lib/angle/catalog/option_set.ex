defmodule Angle.Catalog.OptionSet do
  use Ash.Resource,
    domain: Angle.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [
      AshGraphql.Resource,
      AshJsonApi.Resource,
      AshAdmin.Resource,
      AshTypescript.Resource
    ],
    primary_read_warning?: false

  json_api do
    type "option_set"

    routes do
      base "/option_sets"
      index :read_with_values
      get :read_with_values
      post :create
      post :create_with_values, route: "/create_with_values"
    end
  end

  graphql do
    type :option_set

    queries do
      get :option_set, :read_with_values
      list :option_sets, :read_with_values
    end

    mutations do
      create :create_option_set, :create
      create :create_option_set_with_values, :create_with_values
    end
  end

  postgres do
    table "option_sets"
    repo Angle.Repo

    identity_index_names slug: "option_sets_slug_index"
  end

  typescript do
    type_name "OptionSet"
  end

  actions do
    defaults [:destroy, create: :*, update: :*]

    read :read_with_values do
      primary? true
      description "Read option set with its values loaded"
      prepare build(load: [:option_set_values])
    end

    read :read_with_children do
      description "Read option set with its values and children loaded"
      prepare build(load: [:option_set_values, :children])
    end

    read :read_with_parent do
      description "Read option set with its values and parent loaded"
      prepare build(load: [:option_set_values, :parent])
    end

    read :read_with_descendants do
      description "Read option set with its values, children, and children's values loaded"
      argument :slug, :string, allow_nil?: false
      filter expr(slug == ^arg(:slug))
      prepare build(load: [:option_set_values, children: [:option_set_values]])
    end

    create :create_with_values do
      description "Create an option set with its values"
      accept [:name, :slug, :description, :parent_id]

      argument :values, {:array, :map} do
        description "Array of option set values to create"

        constraints items: [
                      fields: [
                        value: [type: :string, allow_nil?: false],
                        label: [type: :string, allow_nil?: false],
                        metadata: [type: :map, allow_nil?: true],
                        sort_order: [type: :integer, allow_nil?: true],
                        is_active: [type: :boolean, allow_nil?: true]
                      ]
                    ]
      end

      change manage_relationship(:values, :option_set_values,
               type: :direct_control,
               on_no_match: :create
             )

      validate present([:name, :slug])
      validate attribute_does_not_equal(:name, "")
      validate attribute_does_not_equal(:slug, "")
    end
  end

  policies do
    # Public read access to catalog data
    policy action_type(:read) do
      authorize_if always()
    end

    # Admin-only write access to catalog management
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(exists(actor.user_roles, role.name == "admin"))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :parent_id, :uuid do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :option_set_values, Angle.Catalog.OptionSetValue do
      destination_attribute :option_set_id
      source_attribute :id
      public? true
    end

    belongs_to :parent, Angle.Catalog.OptionSet do
      source_attribute :parent_id
      public? true
      attribute_writable? true
    end

    has_many :children, Angle.Catalog.OptionSet do
      destination_attribute :parent_id
      source_attribute :id
      public? true
    end
  end

  identities do
    identity :slug, [:slug]
  end
end
