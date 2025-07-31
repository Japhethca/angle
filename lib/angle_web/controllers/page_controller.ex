defmodule AngleWeb.PageController do
  use AngleWeb, :controller

  @spec home(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def home(conn, _params) do
    render_inertia(conn, :home)
  end
end
