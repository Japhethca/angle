defmodule Angle.Inventory.Item.SearchPreparation do
  @moduledoc """
  Ash preparation that applies tsvector full-text search with pg_trgm fuzzy fallback.
  Adds relevance scoring and orders results by rank.
  """
  use Ash.Resource.Preparation

  require Ash.Query
  require Ash.Sort

  @impl true
  def prepare(query, _opts, _context) do
    case Ash.Query.get_argument(query, :query) do
      nil ->
        query

      "" ->
        query

      search_term ->
        sanitized = sanitize_query(search_term)
        sort_by = Ash.Query.get_argument(query, :sort_by) || :relevance

        query
        |> apply_search_filter(sanitized)
        |> apply_sort(sort_by, sanitized)
    end
  end

  defp apply_search_filter(query, search_term) do
    Ash.Query.filter(
      query,
      expr(
        fragment(
          "(search_vector @@ plainto_tsquery('english', ?) OR similarity(title, ?) > 0.1)",
          ^search_term,
          ^search_term
        )
      )
    )
  end

  defp apply_sort(query, :relevance, search_term) do
    Ash.Query.sort(query, [
      {Ash.Sort.expr_sort(
         fragment(
           "(ts_rank(search_vector, plainto_tsquery('english', ?)) * 2 + similarity(title, ?))",
           ^search_term,
           ^search_term
         )
       ), :desc}
    ])
  end

  defp apply_sort(query, :price_asc, _search_term) do
    Ash.Query.sort(query, current_price: :asc_nils_last)
  end

  defp apply_sort(query, :price_desc, _search_term) do
    Ash.Query.sort(query, current_price: :desc_nils_last)
  end

  defp apply_sort(query, :newest, _search_term) do
    Ash.Query.sort(query, inserted_at: :desc)
  end

  defp apply_sort(query, :ending_soon, _search_term) do
    Ash.Query.sort(query, end_time: :asc_nils_last)
  end

  defp apply_sort(query, _unknown, search_term) do
    apply_sort(query, :relevance, search_term)
  end

  defp sanitize_query(term) do
    term
    |> String.trim()
    |> String.slice(0, 200)
  end
end
