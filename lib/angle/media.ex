defmodule Angle.Media do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshTypescript.Rpc]

  resources do
    resource Angle.Media.Image
  end
end
