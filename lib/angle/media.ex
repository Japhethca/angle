defmodule Angle.Media do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshTypescript.Rpc]

  typescript_rpc do
    resource Angle.Media.Image
  end

  resources do
    resource Angle.Media.Image
  end
end
