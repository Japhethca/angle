defmodule AngleWeb.Helpers.QueryHelpers do
  @moduledoc "Shared helpers for Ash queries in controllers."

  @doc """
  Normalize AshTypescript typed query responses.
  Handles both paginated (%{"results" => [...]}) and plain list responses.
  """
  def extract_results(data) when is_list(data), do: data
  def extract_results(%{"results" => results}) when is_list(results), do: results
  def extract_results(_), do: []
end
