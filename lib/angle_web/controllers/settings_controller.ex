defmodule AngleWeb.SettingsController do
  use AngleWeb, :controller

  def index(conn, _params) do
    conn
    |> assign_prop(:user, user_profile_data(conn))
    |> render_inertia("settings/index")
  end

  def account(conn, _params) do
    conn
    |> assign_prop(:user, user_profile_data(conn))
    |> render_inertia("settings/account")
  end

  defp user_profile_data(conn) do
    user = conn.assigns.current_user

    %{
      id: user.id,
      email: to_string(user.email),
      full_name: user.full_name,
      phone_number: user.phone_number,
      location: user.location
    }
  end
end
