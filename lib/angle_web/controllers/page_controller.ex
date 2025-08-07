defmodule AngleWeb.PageController do
  use AngleWeb, :controller

  @spec home(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def home(conn, _params) do
    # Pass current user data like dashboard controller for proper navigation state
    props =
      case conn.assigns[:current_user] do
        nil -> %{}
        user -> %{user: %{id: user.id, email: user.email, confirmed_at: user.confirmed_at}}
      end

    render_inertia(conn, :home, props)
  end
end
