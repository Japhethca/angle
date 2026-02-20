defmodule Angle.Recommendations do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshAdmin.Domain]

  require Ash.Query
  import Ash.Expr
  alias Angle.Recommendations.Cache

  admin do
    show? true
  end

  resources do
    resource Angle.Recommendations.UserInterest
    resource Angle.Recommendations.ItemSimilarity
    resource Angle.Recommendations.RecommendedItem
  end

  # Public API for serving recommendations

  require Logger

  @doc """
  Get homepage recommendations for a user.
  Falls back to popular items if no personalized recommendations exist.

  Always returns a list of items (may be empty on error).
  """
  def get_homepage_recommendations(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    case Angle.Recommendations.RecommendedItem.get_by_user(
           user_id,
           limit,
           load: [:item],
           authorize?: false
         ) do
      {:ok, recommended_items} ->
        personalized = Enum.map(recommended_items, & &1.item)

        if Enum.empty?(personalized) do
          get_popular_items(limit: limit)
        else
          personalized
        end

      {:error, error} ->
        Logger.warning(
          "Failed to fetch personalized recommendations for user #{user_id}: #{inspect(error)}"
        )

        get_popular_items(limit: limit)
    end
  end

  @doc """
  Get similar items for an item.
  Tries ETS cache first, falls back to database.

  Always returns a list of items (may be empty on error).
  """
  def get_similar_items(item_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 8)

    case Cache.get_similar_items(item_id) do
      {:ok, cached_items} ->
        Enum.take(cached_items, limit)

      {:error, :not_found} ->
        # Cache miss - read from database
        case Angle.Recommendations.ItemSimilarity.find_similar_items(
               item_id,
               limit,
               load: [:similar_item],
               authorize?: false
             ) do
          {:ok, similarities} ->
            Enum.map(similarities, & &1.similar_item)

          {:error, error} ->
            Logger.warning("Failed to fetch similar items for item #{item_id}: #{inspect(error)}")

            []
        end
    end
  end

  @doc """
  Get popular items fallback.
  Tries ETS cache first, falls back to database query.

  Always returns a list of items (may be empty on error).
  """
  def get_popular_items(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    case Cache.get_popular_items() do
      {:ok, cached_items} ->
        Enum.take(cached_items, limit)

      {:error, :not_found} ->
        # Cache miss - query database
        case Angle.Inventory.Item
             |> Ash.Query.filter(expr(publication_status == :published))
             |> Ash.Query.load([:bid_count, :watcher_count])
             |> Ash.Query.sort([{:bid_count, :desc}, {:watcher_count, :desc}])
             |> Ash.Query.limit(limit)
             |> Ash.read(authorize?: false) do
          {:ok, items} ->
            items

          {:error, error} ->
            Logger.warning("Failed to fetch popular items: #{inspect(error)}")
            []
        end
    end
  end
end
