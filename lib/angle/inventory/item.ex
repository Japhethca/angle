defmodule Angle.Inventory.Item do
  use Ash.Resource,
    domain: Angle.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource, AshTypescript.Resource]

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

  graphql do
    type :item

    queries do
      get :item, :read
      list :items, :read
    end

    mutations do
      create :create_draft_item, :create_draft
      update :publish_item, :publish_item
    end
  end

  alias Angle.Inventory.Item.ItemStatus
  alias Angle.Inventory.Item.PublicationStatus

  require Ash.Query

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
          "(((auction_status IS NULL) OR ((auction_status)::text = ANY (ARRAY[('pending'::character varying)::text, ('scheduled'::character varying)::text, ('active'::character varying)::text, ('paused'::character varying)::text, ('ended'::character varying)::text, ('sold'::character varying)::text, ('cancelled'::character varying)::text]))))",
        message: "is invalid"
    end

    identity_index_names slug_title: "items_slug_title_index"
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

  typescript do
    type_name "Item"
  end

  actions do
    defaults [:destroy, create: :*, update: :*]

    read :read do
      primary? true
      pagination offset?: true, required?: false
    end

    create :create_draft do
      description "Create a new item in draft status"

      accept @draft_fields

      # Auto-assign ownership to current user
      change set_attribute(:created_by_id, actor(:id))
    end

    update :update_draft do
      description "Update an existing item in draft status"
      require_atomic? false

      accept @draft_fields

      argument :id, :uuid, allow_nil?: false
      change {Angle.Inventory.Item.MergeAttributes, []}
    end

    update :publish_item do
      description "Publish an item, making it visible to users"
      require_atomic? false

      change set_attribute(:publication_status, :published)
      change {Angle.Inventory.Item.ScheduleEndAuction, []}

      # Strip _auctionDuration from attributes — start_time/end_time are now canonical
      change fn changeset, _context ->
        attrs = Ash.Changeset.get_attribute(changeset, :attributes) || %{}
        cleaned = Map.delete(attrs, "_auctionDuration")
        Ash.Changeset.force_change_attribute(changeset, :attributes, cleaned)
      end
    end

    update :end_auction do
      description "End an auction, setting the final auction status"

      argument :new_status, ItemStatus, allow_nil?: false
      validate one_of(:new_status, [:ended, :sold])
      change set_attribute(:auction_status, arg(:new_status))
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

    read :my_listings do
      description "List all items owned by the current user (for seller dashboard)"

      argument :status_filter, :atom do
        default :all
        constraints one_of: [:all, :active, :ended, :draft]
      end

      argument :sort_field, :atom do
        default :inserted_at

        constraints one_of: [
                      :inserted_at,
                      :view_count,
                      :bid_count,
                      :watcher_count,
                      :current_price
                    ]
      end

      argument :sort_dir, :atom do
        default :desc
        constraints one_of: [:asc, :desc]
      end

      argument :query, :string

      filter expr(created_by_id == ^actor(:id))

      filter expr(
               if ^arg(:status_filter) == :active do
                 publication_status == :published and
                   auction_status in [:pending, :scheduled, :active]
               else
                 if ^arg(:status_filter) == :ended do
                   publication_status == :published and auction_status in [:ended, :sold]
                 else
                   if ^arg(:status_filter) == :draft do
                     publication_status == :draft
                   else
                     true
                   end
                 end
               end
             )

      prepare fn query, _context ->
        case Ash.Query.get_argument(query, :query) do
          nil ->
            query

          "" ->
            query

          search ->
            pattern = "%" <> String.trim(search) <> "%"
            Ash.Query.filter(query, expr(fragment("title ILIKE ?", ^pattern)))
        end
      end

      prepare fn query, _context ->
        field = Ash.Query.get_argument(query, :sort_field) || :inserted_at
        dir = Ash.Query.get_argument(query, :sort_dir) || :desc
        Ash.Query.sort(query, [{field, dir}])
      end

      pagination offset?: true, required?: false
    end

    read :my_listings_stats do
      description "Aggregate stats for all items owned by the current user"
      filter expr(created_by_id == ^actor(:id))
    end

    read :by_category do
      argument :category_ids, {:array, :uuid}, allow_nil?: false

      filter expr(category_id in ^arg(:category_ids) and publication_status == :published)

      pagination offset?: true, required?: false
    end

    read :search do
      description "Full-text search across published items with optional filters"

      argument :query, :string, allow_nil?: false

      argument :category_id, :uuid do
        description "Filter by category"
      end

      argument :condition, :atom do
        constraints one_of: [:new, :used, :refurbished]
      end

      argument :min_price, :decimal
      argument :max_price, :decimal

      argument :sale_type, :atom do
        constraints one_of: [:auction, :buy_now, :hybrid]
      end

      argument :auction_status, :atom do
        constraints one_of: [:pending, :scheduled, :active, :ended, :sold]
      end

      argument :sort_by, :atom do
        default :relevance
        constraints one_of: [:relevance, :price_asc, :price_desc, :newest, :ending_soon]
      end

      filter expr(publication_status == :published)

      filter expr(is_nil(^arg(:category_id)) or category_id == ^arg(:category_id))
      filter expr(is_nil(^arg(:condition)) or condition == ^arg(:condition))
      filter expr(is_nil(^arg(:sale_type)) or sale_type == ^arg(:sale_type))
      filter expr(is_nil(^arg(:auction_status)) or auction_status == ^arg(:auction_status))

      filter expr(
               (is_nil(^arg(:min_price)) or current_price >= ^arg(:min_price)) and
                 (is_nil(^arg(:max_price)) or current_price <= ^arg(:max_price))
             )

      prepare {Angle.Inventory.Item.SearchPreparation, []}

      pagination offset?: true, required?: false
    end

    read :by_seller do
      argument :seller_id, :uuid, allow_nil?: false

      argument :status_filter, :atom do
        default :active
        constraints one_of: [:active, :history]
      end

      filter expr(
               created_by_id == ^arg(:seller_id) and
                 publication_status == :published and
                 ((^arg(:status_filter) == :active and
                     auction_status in [:pending, :scheduled, :active]) or
                    (^arg(:status_filter) == :history and
                       auction_status in [:ended, :sold]))
             )

      pagination offset?: true, required?: false
    end

    read :watchlisted do
      description "List items in the current user's watchlist"

      argument :category_id, :uuid do
        description "Optional category filter"
      end

      filter expr(
               exists(watchlist_items, user_id == ^actor(:id)) and
                 publication_status == :published and
                 (is_nil(^arg(:category_id)) or category_id == ^arg(:category_id))
             )

      pagination offset?: true, required?: false
    end

    read :user_watchlist_ids do
      description "Get IDs of items in the current user's watchlist"

      filter expr(
               exists(watchlist_items, user_id == ^actor(:id)) and
                 publication_status == :published
             )
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

    # Admin bypass for all item modifications
    bypass action_type([:create, :update, :destroy]) do
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "manage_all_items"}
    end

    # Creating items - requires create_items permission
    policy action_type([:create]) do
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "create_items"}
    end

    # Updating items - requires update_own_items permission and ownership
    policy action([:update, :update_draft]) do
      forbid_unless expr(created_by_id == ^actor(:id))
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "update_own_items"}
    end

    # Destroying items - requires delete_own_items permission and ownership
    policy action_type([:destroy]) do
      forbid_unless expr(created_by_id == ^actor(:id))
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "delete_own_items"}
    end

    # Publishing items - requires publish_items permission and ownership
    policy action(:publish_item) do
      forbid_unless expr(created_by_id == ^actor(:id))
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "publish_items"}
    end

    # End auction - system action called by worker, always authorized
    policy action(:end_auction) do
      authorize_if always()
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
      public? true
      default %{}
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

    has_many :bids, Angle.Bidding.Bid do
      destination_attribute :item_id
    end

    has_many :watchlist_items, Angle.Inventory.WatchlistItem do
      destination_attribute :item_id
    end
  end

  aggregates do
    count :bid_count, :bids do
      public? true
    end

    count :watcher_count, :watchlist_items do
      public? true
    end
  end

  identities do
    identity :slug_title, [:slug, :title]
  end
end
