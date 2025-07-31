defmodule Angle.Inventory.ItemActivity do
  use Ash.Resource,
    domain: Angle.Inventory,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "item_activities"
    repo Angle.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :activity_type, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :metadata, :map do
      generated? true
      public? true
    end

    attribute :ip_address, :string do
      sensitive? true
      public? true
    end

    attribute :user_agent, :string do
      public? true
    end

    attribute :session_id, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :item, Angle.Inventory.Item do
      allow_nil? false
      public? true
    end

    belongs_to :user, Angle.Accounts.User do
      public? true
    end
  end
end
