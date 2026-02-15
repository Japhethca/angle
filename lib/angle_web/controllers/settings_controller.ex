defmodule AngleWeb.SettingsController do
  use AngleWeb, :controller

  require Ash.Query

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

  def store(conn, _params) do
    user = conn.assigns.current_user

    store_profile =
      Angle.Accounts.StoreProfile
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read_one!(authorize?: false)

    conn
    |> assign_prop(:user, user_profile_data(conn))
    |> assign_prop(:store_profile, store_profile_data(store_profile))
    |> render_inertia("settings/store")
  end

  defp store_profile_data(nil), do: nil

  defp store_profile_data(profile) do
    %{
      id: profile.id,
      store_name: profile.store_name,
      contact_phone: profile.contact_phone,
      whatsapp_link: profile.whatsapp_link,
      location: profile.location,
      address: profile.address,
      delivery_preference: profile.delivery_preference
    }
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
