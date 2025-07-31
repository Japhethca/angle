defmodule Angle.Inventory do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshAdmin.Domain, AshGraphql.Domain, AshJsonApi.Domain]

  admin do
    show? true
  end

  resources do
    resource Angle.Inventory.Item
    resource Angle.Inventory.ItemActivity
  end
end
