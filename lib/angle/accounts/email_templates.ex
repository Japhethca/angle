defmodule Angle.Accounts.EmailTemplates do
  @moduledoc """
  Branded HTML email templates for Angle.
  """

  @doc """
  Returns a branded HTML email template for OTP verification.
  """
  def otp_verification(code) do
    formatted_code =
      code
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join("-", &Enum.join/1)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="margin: 0; padding: 0; background-color: #f9fafb; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
      <table role="presentation" cellpadding="0" cellspacing="0" style="width: 100%; background-color: #f9fafb;">
        <tr>
          <td align="center" style="padding: 40px 20px;">
            <table role="presentation" cellpadding="0" cellspacing="0" style="width: 100%; max-width: 480px; background-color: #ffffff; border-radius: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
              <tr>
                <td align="center" style="padding: 32px 32px 0;">
                  <span style="font-size: 24px; font-weight: 700; color: #f97316;">ANGLE</span>
                </td>
              </tr>
              <tr>
                <td align="center" style="padding: 24px 32px 8px;">
                  <h1 style="margin: 0; font-size: 22px; font-weight: 700; color: #111827;">Verify your account</h1>
                </td>
              </tr>
              <tr>
                <td align="center" style="padding: 0 32px 24px;">
                  <p style="margin: 0; font-size: 15px; color: #6b7280; line-height: 1.5;">
                    Enter this code to complete your registration. The code expires in 10 minutes.
                  </p>
                </td>
              </tr>
              <tr>
                <td align="center" style="padding: 0 32px 32px;">
                  <div style="display: inline-block; padding: 16px 32px; background-color: #f3f4f6; border-radius: 8px; letter-spacing: 6px; font-size: 32px; font-weight: 700; color: #111827; font-family: monospace;">
                    #{formatted_code}
                  </div>
                </td>
              </tr>
              <tr>
                <td align="center" style="padding: 0 32px 32px;">
                  <p style="margin: 0; font-size: 13px; color: #9ca3af; line-height: 1.5;">
                    If you didn't create an account on Angle, you can safely ignore this email.
                  </p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """
  end
end
