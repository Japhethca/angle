defmodule AngleWeb.PageController do
  use AngleWeb, :controller

  @spec home(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def home(conn, _params) do
    # Auth data is now handled by the auth plug via assign_prop(:auth, ...)
    render_inertia(conn, :home)
  end
end
