defmodule AngleWeb.WatchlistController do
  use AngleWeb, :controller

  def index(conn, _params) do
    render_inertia(conn, "watchlist")
  end
end
