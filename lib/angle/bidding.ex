defmodule Angle.Bidding do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshAdmin.Domain, AshGraphql.Domain, AshJsonApi.Domain, AshTypescript.Rpc]

  admin do
    show? true
  end

  typescript_rpc do
    resource Angle.Bidding.Bid do
      rpc_action :list_bids, :read
      rpc_action :make_bid, :make_bid
    end
  end

  resources do
    resource Angle.Bidding.Bid
    resource Angle.Bidding.Order
  end
end
