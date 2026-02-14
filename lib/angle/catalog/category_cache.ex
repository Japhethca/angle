defmodule Angle.Catalog.CategoryCache do
  @moduledoc """
  ETS-backed cache for navigation categories.
  Caches the nav_category typed query result with a 5-minute TTL.
  """

  use GenServer

  @table :nav_categories_cache
  @ttl_ms :timer.minutes(5)

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Returns cached nav categories. On cache miss or TTL expiry,
  fetches from the nav_category typed query and caches the result.
  """
  def get_nav_categories do
    case :ets.lookup(@table, :nav_categories) do
      [{:nav_categories, data, inserted_at}] ->
        if System.monotonic_time(:millisecond) - inserted_at < @ttl_ms do
          data
        else
          fetch_and_cache()
        end

      [] ->
        fetch_and_cache()
    end
  end

  # Server callbacks

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  # Private

  defp fetch_and_cache do
    case AshTypescript.Rpc.run_typed_query(:angle, :nav_category, %{}, %Plug.Conn{}) do
      %{"success" => true, "data" => data} ->
        results = extract_results(data)
        :ets.insert(@table, {:nav_categories, results, System.monotonic_time(:millisecond)})
        results

      _ ->
        []
    end
  end

  defp extract_results(data) when is_list(data), do: data
  defp extract_results(%{"results" => results}) when is_list(results), do: results
  defp extract_results(_), do: []
end
