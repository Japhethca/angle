defmodule Angle.Bidding.SellerBlacklist do
  use Ash.Resource,
    domain: Angle.Bidding,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "seller_blacklists"
    repo Angle.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:seller_id, :blocked_user_id, :reason]
    end
  end

  policies do
    policy action_type(:read) do
      # Sellers can read their own blacklist
      authorize_if expr(seller_id == ^actor(:id))

      # Admins can read all
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "admin"}
    end

    policy action_type([:create, :update, :destroy]) do
      # Only seller can manage their blacklist
      authorize_if expr(seller_id == ^actor(:id))

      # Admins can manage all
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "admin"}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :seller_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :blocked_user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :reason, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :seller, Angle.Accounts.User do
      source_attribute :seller_id
      allow_nil? false
      public? true
    end

    belongs_to :blocked_user, Angle.Accounts.User do
      source_attribute :blocked_user_id
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_seller_blocked_user, [:seller_id, :blocked_user_id]
  end
end
