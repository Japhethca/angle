defmodule Angle.Recommendations do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    # Resources will be added in subsequent tasks
  end
end
