defmodule Angle.Bidding.Bid do
  use Ash.Resource,
    domain: Angle.Bidding,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  require Ash.Resource.Change.Builtins
  alias Angle.Bidding.Bid.BidType
  alias Angle.Bidding.Bid.ValidateBidIsHigherThanCurrentPrice

  json_api do
    type "bid"

    routes do
      base "/bids"
      index :read
      post :make_bid, route: "/make", name: "Make a Bid"
    end
  end

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

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :make_bid do
      primary? true
      description "Create a new bid for an auction item"
      accept [:amount, :bid_type, :item_id, :user_id]

      validate present([:amount]), message: "Bid amount is required"
      # validate present([:amount]), message: "Bid amount is required"
      # validate present([:bid_type]), message: "Bid type is required"
      # validate present([:item_id]), message: "Item ID is required"

      change {ValidateBidIsHigherThanCurrentPrice, []}

      change before_action(fn changeset, _opts ->
               IO.puts("Validating bid amount against current price...")
               changeset
             end)
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
