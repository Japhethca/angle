defmodule Angle.Recommendations.Cache do
  @moduledoc """
  ETS cache management for recommendations with TTL support.

  Tables:
    - :similar_items_cache - {item_id, {items, inserted_at}}
    - :popular_items_cache - {:homepage_popular, {items, inserted_at}}

  Cache entries include insertion timestamp for TTL-based eviction.
  Default TTL is 24 hours.
  """

  # 24 hours
  @default_ttl_seconds 86_400

  def init do
    # Guard against double initialization (safe for tests and reloads)
    create_table_if_not_exists(:similar_items_cache)
    create_table_if_not_exists(:popular_items_cache)
    :ok
  end

  defp create_table_if_not_exists(table_name) do
    case :ets.info(table_name) do
      :undefined ->
        :ets.new(table_name, [:named_table, :set, :public, read_concurrency: true])

      _ ->
        # Table already exists, skip creation
        :ok
    end
  end

  def get_similar_items(item_id, opts \\ []) do
    max_age_seconds = Keyword.get(opts, :max_age_seconds, @default_ttl_seconds)

    case :ets.lookup(:similar_items_cache, item_id) do
      [{^item_id, {items, inserted_at}}] ->
        age_seconds = System.system_time(:second) - inserted_at

        if age_seconds <= max_age_seconds do
          {:ok, items}
        else
          {:error, :stale}
        end

      [] ->
        {:error, :not_found}
    end
  end

  def put_similar_items(item_id, items) do
    timestamp = System.system_time(:second)
    :ets.insert(:similar_items_cache, {item_id, {items, timestamp}})
    :ok
  end

  def get_popular_items(opts \\ []) do
    max_age_seconds = Keyword.get(opts, :max_age_seconds, @default_ttl_seconds)

    case :ets.lookup(:popular_items_cache, :homepage_popular) do
      [{:homepage_popular, {items, inserted_at}}] ->
        age_seconds = System.system_time(:second) - inserted_at

        if age_seconds <= max_age_seconds do
          {:ok, items}
        else
          {:error, :stale}
        end

      [] ->
        {:error, :not_found}
    end
  end

  def put_popular_items(items) do
    timestamp = System.system_time(:second)
    :ets.insert(:popular_items_cache, {:homepage_popular, {items, timestamp}})
    :ok
  end

  def get_stats do
    similar_info = :ets.info(:similar_items_cache)
    popular_info = :ets.info(:popular_items_cache)

    %{
      similar_items: %{
        size: similar_info[:size],
        memory_words: similar_info[:memory]
      },
      popular_items: %{
        size: popular_info[:size],
        memory_words: popular_info[:memory]
      }
    }
  end

  def clear_all do
    :ets.delete_all_objects(:similar_items_cache)
    :ets.delete_all_objects(:popular_items_cache)
    :ok
  end
end
