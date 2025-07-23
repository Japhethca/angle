defmodule Angle.Accounts do
  use Ash.Domain, otp_app: :angle, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Angle.Accounts.Token
    resource Angle.Accounts.User
  end
end
