defmodule AngleWeb.Plugs.NavCategories do
  @moduledoc """
  Assigns nav_categories as a shared Inertia prop from the ETS cache.
  """

  import Inertia.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    categories = Angle.Catalog.CategoryCache.get_nav_categories()
    assign_prop(conn, :nav_categories, categories)
  end
end
