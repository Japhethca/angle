defmodule Angle.Media do
  use Ash.Domain,
    otp_app: :angle

  resources do
    resource Angle.Media.Image
  end
end
