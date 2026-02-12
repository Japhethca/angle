defmodule AngleWeb.AuthPlug do
  @moduledoc """
  Authentication plug for handling OAuth callbacks (Google, etc.).
  Delegates to AshAuthentication for strategy-specific routing.
  """

  use AshAuthentication.Plug, otp_app: :angle

  def handle_success(conn, _activity, user, token) do
    conn =
      conn
      |> store_in_session(user)
      |> Plug.Conn.put_session(:current_user_id, user.id)
      |> maybe_store_token(token)

    {conn, redirect_to} = AngleWeb.Plugs.Auth.pop_return_to(conn, "/dashboard")

    conn
    |> Phoenix.Controller.put_flash(:info, "Successfully signed in!")
    |> Phoenix.Controller.redirect(to: redirect_to)
  end

  def handle_failure(conn, _activity, _reason) do
    conn
    |> Phoenix.Controller.put_flash(:error, "Authentication failed. Please try again.")
    |> Phoenix.Controller.redirect(to: "/auth/login")
  end

  defp maybe_store_token(conn, nil), do: conn

  defp maybe_store_token(conn, token) do
    Plug.Conn.put_session(conn, :auth_token, token)
  end
end
