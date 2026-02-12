defmodule AngleWeb.ItemsController do
  use AngleWeb, :controller

  def new(conn, _params) do
    render_inertia(conn, "items/new")
  end
end
