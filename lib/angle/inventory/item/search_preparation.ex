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
    search_term = Ash.Query.get_argument(query, :query)
    sort_by = Ash.Query.get_argument(query, :sort_by) || :relevance

    query =
      case search_term do
        nil ->
          query

        "" ->
          query

        term ->
          sanitized = sanitize_query(term)
          apply_search_filter(query, sanitized)
      end

    # When no search term, can't use relevance sort (needs search term for fragment)
    # Default to :newest for filter-only browsing
    effective_sort =
      if (is_nil(search_term) or search_term == "") and sort_by == :relevance do
        :newest
      else
        sort_by
      end

    apply_sort(query, effective_sort, search_term || "")
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

  defp apply_sort(query, :view_count_desc, _search_term) do
    Ash.Query.sort(query, view_count: :desc_nils_last)
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
