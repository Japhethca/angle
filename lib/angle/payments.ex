defmodule Angle.Payments do
  use Ash.Domain,
    otp_app: :angle

  resources do
    resource Angle.Payments.PaymentMethod
    resource Angle.Payments.PayoutMethod
  end
end
