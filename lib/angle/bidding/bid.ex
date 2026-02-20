defmodule Angle.Bidding.Bid do
  use Ash.Resource,
    domain: Angle.Bidding,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource, AshTypescript.Resource]

  json_api do
    type "bid"

    routes do
      base "/bids"
      index :read
      post :make_bid, route: "/make", name: "Make a Bid"
    end
  end

  require Ash.Resource.Change.Builtins
  alias Angle.Bidding.Bid.BidType
  alias Angle.Bidding.Bid.ValidateBidIsHigherThanCurrentPrice

  graphql do
    type :bid

    queries do
      get :bid, :read
      list :bids, :read
    end

    mutations do
      create :make_bid, :make_bid
    end
  end

  postgres do
    table "bids"
    repo Angle.Repo
  end

  typescript do
    type_name "Bid"
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :make_bid do
      primary? true
      description "Create a new bid for an auction item"
      accept [:amount, :bid_type, :item_id]

      validate present([:amount]), message: "Bid amount is required"

      # Auto-assign the bidder to current user
      change set_attribute(:user_id, actor(:id))

      change {ValidateBidIsHigherThanCurrentPrice, []}
    end

    read :by_user_since do
      description "List bids for a user placed after a specific timestamp"

      argument :user_id, :uuid, allow_nil?: false
      argument :since, :utc_datetime, allow_nil?: false

      filter expr(user_id == ^arg(:user_id) and bid_time > ^arg(:since))
    end

    read :by_item_ids do
      description "List bids for multiple items (for recommendation scoring)"

      argument :item_ids, {:array, :uuid}, allow_nil?: false

      filter expr(item_id in ^arg(:item_ids))
    end
  end

  policies do
    # Reading bids - requires view_bids permission
    policy action_type(:read) do
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "view_bids"}
    end

    # by_user_since action for recommendation engine - background jobs bypass authorization
    policy action(:by_user_since) do
      authorize_if expr(user_id == ^actor(:id))
    end

    # by_item_ids action for recommendation engine - background jobs bypass authorization
    policy action(:by_item_ids) do
      authorize_if always()
    end

    # Creating bids - requires place_bids permission
    # Ownership is enforced by the action's set_attribute(:user_id, actor(:id))
    policy action(:make_bid) do
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "place_bids"}
    end

    # Managing bids - admin only
    policy action_type([:update, :destroy]) do
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "manage_bids"}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :amount, :decimal do
      allow_nil? false
      public? true
      description "The amount of the bid"
    end

    attribute :bid_type, BidType do
      allow_nil? false
      public? true
      description "The type of the bid"
    end

    attribute :item_id, :uuid do
      allow_nil? false
      public? true
      description "The ID of the item being bid on"
    end

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
      description "The ID of the user placing the bid"
    end

    create_timestamp :bid_time do
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :item, Angle.Inventory.Item do
      public? true
    end

    belongs_to :user, Angle.Accounts.User do
      public? true
    end
  end
end
