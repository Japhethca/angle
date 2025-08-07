defmodule Angle.Inventory.Item do
  use Ash.Resource,
    domain: Angle.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  alias Angle.Inventory.Item.ItemStatus
  alias Angle.Inventory.Item.PublicationStatus

  json_api do
    type "item"

    routes do
      base "/items"
      index :read, primary?: true, name: "All Items"
      post :create, name: "Create Item"
      post :create_draft, route: "/draft", name: "Create Draft Item"
      patch :update_draft, route: "/draft/:id", name: "Update Draft Item"
      patch :publish_item, route: "/publish", name: "Publish Item"
    end
  end

  @draft_fields [
    :title,
    :description,
    :starting_price,
    :reserve_price,
    :bid_increment,
    :slug,
    :start_time,
    :end_time,
    :category_id,
    :lot_number,
    :condition,
    :location,
    :attributes,
    :sale_type,
    :auction_format,
    :buy_now_price
  ]

  postgres do
    table "items"
    repo Angle.Repo

    custom_indexes do
      index [:auction_status, :publication_status] do
        name "items_published_auction_idx"

        where "(((publication_status)::text = 'published'::text) AND ((auction_status)::text = ANY ((ARRAY['scheduled'::character varying, 'active'::character varying, 'ended'::character varying])::text[])))"
      end
    end

    check_constraints do
      check_constraint :id, "valid_auction_status",
        check:
          "(((auction_status IS NULL) OR ((auction_status)::text = ANY (ARRAY[('scheduled'::character varying)::text, ('active'::character varying)::text, ('paused'::character varying)::text, ('ended'::character varying)::text, ('sold'::character varying)::text, ('cancelled'::character varying)::text]))))",
        message: "is invalid"
    end

    identity_index_names slug_title: "items_slug_title_index"
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :create_draft do
      description "Create a new item in draft status"

      accept @draft_fields

      # Auto-assign ownership to current user
      change set_attribute(:created_by_id, actor(:id))
    end

    update :update_draft do
      description "Update an existing item in draft status"

      accept @draft_fields

      argument :id, :uuid, allow_nil?: false
    end

    update :publish_item do
      description "Publish an item, making it visible to users"

      change set_attribute(:publication_status, :published)
    end

    read :test_item do
      argument :name, :string, allow_nil?: false

      # prepare fn query, context ->
      #   IO.inspect(context, label: "Test Item context")
      #   IO.inspect(query, label: "Test Item query")
      #   {:ok, query}
      # end
      # prepare build())
    end
  end

  policies do
    # Reading items - published items are public, own items are visible to owner
    policy action_type(:read) do
      # Public published items
      authorize_if expr(publication_status == :published)

      # Own items
      authorize_if expr(created_by_id == ^actor(:id))
    end

    # Creating items - requires create_items permission
    policy action_type([:create]) do
      authorize_if expr(
                     exists(
                       actor.user_roles,
                       exists(role.role_permissions, permission.name == "create_items")
                     )
                   )
    end

    # Updating items - requires update_own_items permission and ownership
    policy action_type([:update]) do
      authorize_if expr(
                     created_by_id == ^actor(:id) and
                       exists(
                         actor.user_roles,
                         exists(role.role_permissions, permission.name == "update_own_items")
                       )
                   )

      # Admins can update all items
      authorize_if expr(
                     exists(
                       actor.user_roles,
                       exists(role.role_permissions, permission.name == "manage_all_items")
                     )
                   )
    end

    # Destroying items - requires delete_own_items permission and ownership
    policy action_type([:destroy]) do
      authorize_if expr(
                     created_by_id == ^actor(:id) and
                       exists(
                         actor.user_roles,
                         exists(role.role_permissions, permission.name == "delete_own_items")
                       )
                   )

      # Admins can delete all items
      authorize_if expr(
                     exists(
                       actor.user_roles,
                       exists(role.role_permissions, permission.name == "manage_all_items")
                     )
                   )
    end

    # Publishing items - requires publish_items permission and ownership
    policy action(:publish_item) do
      authorize_if expr(
                     created_by_id == ^actor(:id) and
                       exists(
                         actor.user_roles,
                         exists(role.role_permissions, permission.name == "publish_items")
                       )
                   )

      # Admins can publish all items
      authorize_if expr(
                     exists(
                       actor.user_roles,
                       exists(role.role_permissions, permission.name == "manage_all_items")
                     )
                   )
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :starting_price, :decimal do
      public? true
      allow_nil? false
      constraints greater_than: 0
    end

    attribute :reserve_price, :decimal do
      public? true
    end

    attribute :current_price, :decimal do
      public? true
    end

    attribute :bid_increment, :decimal do
      public? true
    end

    attribute :slug, :string do
      public? true
    end

    attribute :start_time, :utc_datetime_usec do
      public? true
    end

    attribute :end_time, :utc_datetime_usec do
      public? true
    end

    attribute :category_id, :uuid do
      public? true
    end

    attribute :lot_number, :string do
      public? true
    end

    attribute :publication_status, PublicationStatus do
      generated? true
      public? true
      default :draft
    end

    attribute :auction_status, ItemStatus do
      generated? true
      public? true
      default :pending
    end

    attribute :condition, :atom do
      generated? true
      public? true
      default :new
      constraints one_of: [:new, :used, :refurbished]
    end

    attribute :location, :string do
      public? true
    end

    attribute :attributes, :map do
      allow_nil? false
      generated? true
      public? true
    end

    attribute :sale_type, :atom do
      allow_nil? false
      generated? true
      public? true
      default :auction
      constraints one_of: [:auction, :buy_now, :hybrid]
    end

    attribute :auction_format, :atom do
      generated? true
      public? true
      default :standard
      constraints one_of: [:standard, :reserve, :live, :timed]
    end

    attribute :buy_now_price, :decimal do
      public? true
      constraints greater_than: 0
    end

    attribute :view_count, :integer do
      default 0
      generated? true
      public? true
    end

    attribute :created_by_id, :uuid do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      source_attribute :created_by_id
      public? true
    end

    belongs_to :category, Angle.Catalog.Category do
      source_attribute :category_id
      public? true
    end
  end

  identities do
    identity :slug_title, [:slug, :title]
  end
end
