defmodule Angle.Recommendations.Cache do
  @moduledoc """
  ETS cache management for recommendations.

  Tables:
    - :similar_items_cache - item_id → list of similar items
    - :popular_items_cache - :homepage_popular → list of items
  """

  def init do
    :ets.new(:similar_items_cache, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(:popular_items_cache, [:named_table, :set, :public, read_concurrency: true])
    :ok
  end

  def get_similar_items(item_id) do
    case :ets.lookup(:similar_items_cache, item_id) do
      [{^item_id, items}] -> {:ok, items}
      [] -> {:error, :not_found}
    end
  end

  def put_similar_items(item_id, items) do
    :ets.insert(:similar_items_cache, {item_id, items})
    :ok
  end

  def get_popular_items do
    case :ets.lookup(:popular_items_cache, :homepage_popular) do
      [{:homepage_popular, items}] -> {:ok, items}
      [] -> {:error, :not_found}
    end
  end

  def put_popular_items(items) do
    :ets.insert(:popular_items_cache, {:homepage_popular, items})
    :ok
  end

  def clear_all do
    :ets.delete_all_objects(:similar_items_cache)
    :ets.delete_all_objects(:popular_items_cache)
    :ok
  end
end
