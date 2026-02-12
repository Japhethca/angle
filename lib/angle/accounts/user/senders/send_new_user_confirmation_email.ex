defmodule Angle.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Sends a branded OTP verification email for new user confirmation.

  Instead of sending a clickable link, generates a 6-digit OTP code,
  stores it mapped to the JWT confirmation token, and sends the code
  via a branded HTML email.
  """

  use AshAuthentication.Sender

  import Swoosh.Email

  alias Angle.Accounts.{EmailTemplates, OtpHelper}
  alias Angle.Mailer

  @impl true
  def send(user, token, _opts) do
    otp = OtpHelper.create_otp(user.id, token, "confirm_new_user")

    {sender_name, sender_email} =
      Application.get_env(:angle, :sender_email, {"Angle", "noreply@angle.app"})

    new()
    |> from({sender_name, sender_email})
    |> to(to_string(user.email))
    |> subject("Your Angle verification code: #{otp.code}")
    |> html_body(EmailTemplates.otp_verification(otp.code))
    |> Mailer.deliver!()
  end
end
