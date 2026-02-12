defmodule AngleWeb.SettingsController do
  use AngleWeb, :controller

  def index(conn, _params) do
    render_inertia(conn, "settings")
  end
end
