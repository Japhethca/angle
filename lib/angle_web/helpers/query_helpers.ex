defmodule AngleWeb.Helpers.QueryHelpers do
  @moduledoc "Shared helpers for Ash queries in controllers."

  require Ash.Query

  @doc """
  Normalize AshTypescript typed query responses.
  Handles both paginated (%{"results" => [...]}) and plain list responses.
  """
  def extract_results(data) when is_list(data), do: data
  def extract_results(%{"results" => results}) when is_list(results), do: results
  def extract_results(_), do: []

  @doc "Build a map of item_id => watchlist_entry_id for the current user."
  def load_watchlisted_map(conn) do
    case conn.assigns[:current_user] do
      nil ->
        %{}

      user ->
        case Angle.Inventory.list_watchlist_by_user(actor: user, authorize?: false) do
          {:ok, entries} -> Map.new(entries, fn entry -> {entry.item_id, entry.id} end)
          _ -> %{}
        end
    end
  end

  @doc "Build a list of categories with item counts for a seller."
  def build_category_summary(seller_id) do
    item_query =
      Angle.Inventory.Item
      |> Ash.Query.filter(created_by_id == ^seller_id and publication_status == :published)

    case Angle.Catalog.Category
         |> Ash.Query.aggregate(:item_count, :count, :items, query: item_query, default: 0)
         |> Ash.read(authorize?: false) do
      {:ok, categories} ->
        categories
        |> Enum.filter(fn cat -> cat.aggregates[:item_count] > 0 end)
        |> Enum.sort_by(fn cat -> -cat.aggregates[:item_count] end)
        |> Enum.map(fn cat ->
          %{
            "id" => cat.id,
            "name" => cat.name,
            "slug" => cat.slug,
            "count" => cat.aggregates[:item_count]
          }
        end)

      _ ->
        []
    end
  end
end
