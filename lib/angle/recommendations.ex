defmodule Angle.Recommendations do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Angle.Recommendations.UserInterest
    resource Angle.Recommendations.ItemSimilarity
  end
end
