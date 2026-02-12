defmodule AngleWeb.ProfileController do
  use AngleWeb, :controller

  def show(conn, _params) do
    render_inertia(conn, "profile")
  end
end
