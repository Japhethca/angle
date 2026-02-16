defmodule Angle.Bidding.Review do
  @moduledoc "Represents a buyer's review of a seller after a completed order."

  use Ash.Resource,
    domain: Angle.Bidding,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  postgres do
    table "reviews"
    repo Angle.Repo
  end

  typescript do
    type_name "Review"
  end

  actions do
    defaults []

    create :create do
      accept [:order_id, :rating, :comment]
      change set_attribute(:reviewer_id, actor(:id))
      change Angle.Bidding.Review.SetSellerFromOrder
      change Angle.Bidding.Review.ValidateOrderCompleted
      change Angle.Bidding.Review.ValidateReviewWindow
    end

    update :update do
      accept [:rating, :comment]
      require_atomic? false
      change Angle.Bidding.Review.ValidateEditWindow
    end

    read :read do
      primary? true
      pagination offset?: true, required?: false
    end

    read :by_seller do
      argument :seller_id, :uuid, allow_nil?: false
      filter expr(seller_id == ^arg(:seller_id))
      prepare build(sort: [inserted_at: :desc])
      pagination offset?: true, required?: false
    end

    read :for_order do
      argument :order_id, :uuid, allow_nil?: false
      filter expr(order_id == ^arg(:order_id))
    end
  end

  policies do
    policy action(:create) do
      authorize_if Angle.Bidding.Review.CheckActorIsOrderBuyer
    end

    policy action(:update) do
      authorize_if expr(reviewer_id == ^actor(:id))
    end

    policy action([:read, :by_seller, :for_order]) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :rating, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 5
    end

    attribute :comment, :string do
      public? true
    end

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :order, Angle.Bidding.Order do
      allow_nil? false
      public? true
    end

    belongs_to :reviewer, Angle.Accounts.User do
      allow_nil? false
      public? true
    end

    belongs_to :seller, Angle.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_order_review, [:order_id]
  end
end
