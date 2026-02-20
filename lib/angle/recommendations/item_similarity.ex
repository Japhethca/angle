defmodule Angle.Recommendations.ItemSimilarity do
  @moduledoc """
  Stores pre-computed similarity scores between items.

  Similarity is computed by SimilarityScorer using:
  - Category match (weight: 0.5)
  - Price range overlap (weight: 0.3)
  - Collaborative signal from shared users (weight: 0.2)

  Populated by ComputeItemSimilarity job (to be implemented).
  """

  use Ash.Resource,
    domain: Angle.Recommendations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "item_similarities"
    repo Angle.Repo

    custom_indexes do
      index [:source_item_id, :similarity_score]
    end
  end

  code_interface do
    domain Angle.Recommendations
    define :create_similarity, action: :create

    define :find_similar_items,
      action: :by_source_item,
      args: [:source_item_id, {:optional, :limit}]
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:similarity_score, :reason]

      argument :source_item_id, :uuid, allow_nil?: false
      argument :similar_item_id, :uuid, allow_nil?: false

      change set_attribute(:source_item_id, arg(:source_item_id))
      change set_attribute(:similar_item_id, arg(:similar_item_id))
    end

    update :update do
      primary? true
      accept [:similarity_score, :reason]
    end

    destroy :destroy do
      primary? true
    end

    read :by_source_item do
      argument :source_item_id, :uuid, allow_nil?: false
      argument :limit, :integer, default: 20

      filter expr(source_item_id == ^arg(:source_item_id))

      prepare fn query, _context ->
        query
        |> Ash.Query.sort(similarity_score: :desc)
        |> Ash.Query.limit(Ash.Query.get_argument(query, :limit))
      end
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

    attribute :similarity_score, :float do
      allow_nil? false
      public? true
      constraints min: 0.0, max: 1.0
    end

    attribute :reason, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:same_category, :price_range, :collaborative]
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :source_item, Angle.Inventory.Item do
      allow_nil? false
      attribute_writable? true
      attribute_public? true
      source_attribute :source_item_id
    end

    belongs_to :similar_item, Angle.Inventory.Item do
      allow_nil? false
      attribute_writable? true
      attribute_public? true
      source_attribute :similar_item_id
    end
  end

  identities do
    identity :unique_source_similar, [:source_item_id, :similar_item_id]
  end
end
