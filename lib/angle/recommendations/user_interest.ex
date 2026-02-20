defmodule Angle.Recommendations.UserInterest do
  @moduledoc """
  Tracks user interest scores per category based on their activity.

  Interest scores are computed by InterestScorer using:
  - Bid history (weight: 3.0)
  - Watchlist activity (weight: 2.0)
  - Time decay based on recency

  Scores are normalized to 0.0-1.0 range, updated by RefreshUserInterests job.
  """

  use Ash.Resource,
    domain: Angle.Recommendations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "user_interests"
    repo Angle.Repo

    custom_indexes do
      index [:user_id, :interest_score]
    end
  end

  code_interface do
    domain Angle.Recommendations
    define :create_interest, action: :create
    define :upsert_interest, action: :upsert
    define :get_by_user, action: :by_user
    define :get_top_interests, action: :top_interests
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:interest_score, :last_interaction_at, :interaction_count]

      argument :user_id, :uuid, allow_nil?: false
      argument :category_id, :uuid, allow_nil?: false

      change set_attribute(:user_id, arg(:user_id))
      change set_attribute(:category_id, arg(:category_id))
    end

    update :update do
      primary? true
      accept [:interest_score, :last_interaction_at, :interaction_count]
    end

    create :upsert do
      accept [:interest_score, :last_interaction_at, :interaction_count]
      upsert? true
      upsert_identity :unique_user_category
      upsert_fields [:interest_score, :last_interaction_at, :interaction_count]

      argument :user_id, :uuid, allow_nil?: false
      argument :category_id, :uuid, allow_nil?: false

      change set_attribute(:user_id, arg(:user_id))
      change set_attribute(:category_id, arg(:category_id))
    end

    destroy :destroy do
      primary? true
    end

    read :by_user do
      argument :user_id, :uuid, allow_nil?: false

      filter expr(user_id == ^arg(:user_id))
    end

    read :top_interests do
      argument :user_id, :uuid, allow_nil?: false
      argument :limit, :integer, default: 5

      filter expr(user_id == ^arg(:user_id))

      prepare fn query, _context ->
        query
        |> Ash.Query.sort(interest_score: :desc)
        |> Ash.Query.limit(Ash.Query.get_argument(query, :limit))
      end
    end
  end

  policies do
    # Users can read their own interests
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
    end

    # Admin bypass for all actions
    bypass action_type([:create, :update, :destroy]) do
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "manage_recommendations"}
    end

    # Default deny write operations (background jobs use authorize?: false)
    policy action_type([:create, :update, :destroy]) do
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :interest_score, :float do
      allow_nil? false
      default 0.0
      public? true
      constraints min: 0.0, max: 1.0
    end

    attribute :last_interaction_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    attribute :interaction_count, :integer do
      allow_nil? false
      default 0
      public? true
      constraints min: 0
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

    belongs_to :category, Angle.Catalog.Category do
      allow_nil? false
      attribute_writable? true
      attribute_public? true
    end
  end

  identities do
    identity :unique_user_category, [:user_id, :category_id]
  end
end
