defmodule Angle.Bidding do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshAdmin.Domain, AshGraphql.Domain, AshJsonApi.Domain]

  admin do
    show? true
  end

  resources do
    resource Angle.Bidding.Bid
  end
end
