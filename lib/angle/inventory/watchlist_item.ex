defmodule Angle.Inventory.WatchlistItem do
  use Ash.Resource,
    domain: Angle.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  postgres do
    table "watchlist_items"
    repo Angle.Repo
  end

  typescript do
    type_name "WatchlistItem"
  end

  actions do
    defaults []

    create :add do
      description "Add an item to the user's watchlist"
      accept [:item_id]
      change set_attribute(:user_id, actor(:id))
    end

    destroy :remove do
      description "Remove an item from the user's watchlist"
      primary? true
    end

    read :by_user do
      description "List watchlist items for the current user"
      filter expr(user_id == ^actor(:id))
    end

    read :by_user_since do
      description "List watchlist items for a user added after a specific timestamp"

      argument :user_id, :uuid, allow_nil?: false
      argument :since, :utc_datetime, allow_nil?: false

      filter expr(user_id == ^arg(:user_id) and inserted_at > ^arg(:since))
    end

    read :read do
      primary? true
    end
  end

  policies do
    policy action(:add) do
      authorize_if actor_present()
    end

    policy action(:remove) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action(:by_user) do
      authorize_if actor_present()
    end

    policy action(:by_user_since) do
      # Background jobs will bypass authorization
      # Human access should check if they're requesting their own data
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action(:read) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :item_id, :uuid do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      source_attribute :user_id
      public? true
    end

    belongs_to :item, Angle.Inventory.Item do
      source_attribute :item_id
      public? true
    end
  end

  identities do
    identity :unique_user_item, [:user_id, :item_id]
  end
end
