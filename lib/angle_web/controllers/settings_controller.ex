defmodule AngleWeb.SettingsController do
  use AngleWeb, :controller

  require Ash.Query

  alias AngleWeb.ImageHelpers

  def index(conn, _params) do
    conn
    |> assign_prop(:user, user_profile_data(conn))
    |> render_inertia("settings/index")
  end

  def account(conn, _params) do
    user = conn.assigns.current_user

    avatar_images =
      Angle.Media.Image
      |> Ash.Query.for_read(:by_owner, %{owner_type: :user_avatar, owner_id: user.id},
        authorize?: false
      )
      |> Ash.read!()
      |> Enum.map(&ImageHelpers.serialize_image/1)

    conn
    |> assign_prop(:user, user_profile_data(conn))
    |> assign_prop(:avatar_images, avatar_images)
    |> render_inertia("settings/account")
  end

  def security(conn, _params) do
    conn
    |> assign_prop(:user, user_profile_data(conn))
    |> render_inertia("settings/security")
  end

  def payments(conn, _params) do
    user = conn.assigns.current_user

    payment_methods =
      Angle.Payments.PaymentMethod
      |> Ash.read!(action: :list_by_user, actor: user)
      |> Enum.map(&payment_method_data/1)

    payout_methods =
      Angle.Payments.PayoutMethod
      |> Ash.read!(action: :list_by_user, actor: user)
      |> Enum.map(&payout_method_data/1)

    conn
    |> assign_prop(:user, user_payments_data(conn))
    |> assign_prop(:payment_methods, payment_methods)
    |> assign_prop(:payout_methods, payout_methods)
    |> render_inertia("settings/payments")
  end

  def notifications(conn, _params) do
    conn
    |> assign_prop(:user, user_notifications_data(conn))
    |> render_inertia("settings/notifications")
  end

  def preferences(conn, _params) do
    conn
    |> assign_prop(:user, user_profile_data(conn))
    |> render_inertia("settings/preferences")
  end

  def legal(conn, _params) do
    conn
    |> render_inertia("settings/legal")
  end

  def support(conn, _params) do
    conn
    |> render_inertia("settings/support")
  end

  def store(conn, _params) do
    user = conn.assigns.current_user

    store_profile =
      Angle.Accounts.StoreProfile
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read_one!(authorize?: false)

    logo_images =
      case store_profile do
        nil ->
          []

        profile ->
          Angle.Media.Image
          |> Ash.Query.for_read(:by_owner, %{owner_type: :store_logo, owner_id: profile.id},
            authorize?: false
          )
          |> Ash.read!()
          |> Enum.map(&ImageHelpers.serialize_image/1)
      end

    conn
    |> assign_prop(:user, user_profile_data(conn))
    |> assign_prop(:store_profile, store_profile_data(store_profile))
    |> assign_prop(:logo_images, logo_images)
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

  defp user_notifications_data(conn) do
    user = conn.assigns.current_user

    prefs =
      case user.notification_preferences do
        %Angle.Accounts.NotificationPreferences{} = p -> p
        _ -> %Angle.Accounts.NotificationPreferences{}
      end

    %{
      id: user.id,
      notification_preferences:
        Map.take(prefs, [
          :push_bidding,
          :push_watchlist,
          :push_payments,
          :push_communication,
          :email_communication,
          :email_marketing,
          :email_security,
          :sms_communication,
          :sms_security
        ])
    }
  end

  defp user_payments_data(conn) do
    user = conn.assigns.current_user

    %{
      id: user.id,
      email: to_string(user.email),
      auto_charge: user.auto_charge
    }
  end

  defp payment_method_data(method) do
    %{
      id: method.id,
      card_type: method.card_type,
      last_four: method.last_four,
      exp_month: method.exp_month,
      exp_year: method.exp_year,
      bank: method.bank,
      is_default: method.is_default,
      inserted_at: method.inserted_at
    }

    # NOTE: authorization_code and paystack_reference are NOT included (security)
  end

  defp payout_method_data(method) do
    %{
      id: method.id,
      bank_name: method.bank_name,
      account_number: mask_account_number(method.account_number),
      account_name: method.account_name,
      is_default: method.is_default,
      inserted_at: method.inserted_at
    }

    # NOTE: recipient_code and bank_code are NOT included (security)
  end

  defp mask_account_number(number) when is_binary(number) and byte_size(number) > 6 do
    visible = String.slice(number, 0, 6)
    masked = String.duplicate("*", String.length(number) - 6)
    visible <> masked
  end

  defp mask_account_number(number), do: number
end
