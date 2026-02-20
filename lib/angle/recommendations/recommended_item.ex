defmodule Angle.Recommendations.RecommendedItem do
  @moduledoc """
  Stores pre-computed item recommendations for users.

  Each record represents a recommended item for a specific user with a score,
  reason, and rank. Used to power personalized homepage recommendations.
  """
  use Ash.Resource,
    domain: Angle.Recommendations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "recommended_items"
    repo Angle.Repo

    custom_indexes do
      index [:user_id, :rank]
      index [:generated_at]
    end
  end

  code_interface do
    domain Angle.Recommendations
    define :create_recommendation, action: :create
    define :get_user_recommendations, action: :by_user
    define :get_by_user, action: :by_user
    define :find_stale_recommendations, action: :stale_recommendations
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:recommendation_score, :recommendation_reason, :rank, :generated_at]

      argument :user_id, :uuid, allow_nil?: false
      argument :item_id, :uuid, allow_nil?: false

      change set_attribute(:user_id, arg(:user_id))
      change set_attribute(:item_id, arg(:item_id))
    end

    update :update do
      primary? true
      accept [:recommendation_score, :recommendation_reason, :rank]
    end

    destroy :destroy do
      primary? true
    end

    read :by_user do
      argument :user_id, :uuid, allow_nil?: false
      argument :limit, :integer, default: 20

      filter expr(user_id == ^arg(:user_id))

      prepare fn query, _context ->
        query
        |> Ash.Query.sort(rank: :asc)
        |> Ash.Query.limit(Ash.Query.get_argument(query, :limit))
      end
    end

    read :stale_recommendations do
      argument :cutoff, :utc_datetime, allow_nil?: false

      filter expr(generated_at < ^arg(:cutoff))
    end
  end

  policies do
    # NOTE: Permissive policy for internal background job use only
    # TODO: Add proper authorization if exposed to users
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :recommendation_score, :float do
      allow_nil? false
      public? true
      constraints min: 0.0, max: 1.0
    end

    attribute :recommendation_reason, :string do
      public? true
    end

    attribute :rank, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :generated_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      allow_nil? false
      attribute_writable? true
      attribute_public? true
    end

    belongs_to :item, Angle.Inventory.Item do
      allow_nil? false
      attribute_writable? true
      attribute_public? true
    end
  end

  identities do
    identity :unique_user_item, [:user_id, :item_id]
  end
end
