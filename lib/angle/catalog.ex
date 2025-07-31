defmodule Angle.Catalog do
  use Ash.Domain, otp_app: :angle, extensions: [AshAdmin.Domain, AshJsonApi.Domain]

  admin do
    show? true
  end

  resources do
    resource Angle.Catalog.Category
  end
end
