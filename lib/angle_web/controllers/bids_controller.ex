defmodule AngleWeb.BidsController do
  use AngleWeb, :controller

  def index(conn, _params) do
    render_inertia(conn, "bids")
  end
end
