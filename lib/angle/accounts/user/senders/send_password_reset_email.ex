defmodule Angle.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """

  use AshAuthentication.Sender
  use AngleWeb, :verified_routes

  import Swoosh.Email

  alias Angle.Mailer

  @impl true
  def send(user, token, _) do
    {sender_name, sender_email} =
      Application.get_env(:angle, :sender_email, {"Angle", "noreply@angle.app"})

    new()
    |> from({sender_name, sender_email})
    |> to(to_string(user.email))
    |> subject("Reset your password")
    |> html_body(body(token: token))
    |> Mailer.deliver!()
  end

  defp body(params) do
    url = url(~p"/auth/reset-password/#{params[:token]}")

    """
    <p>Click this link to reset your password:</p>
    <p><a href="#{url}">#{url}</a></p>
    """
  end
end
