defmodule Angle.Catalog do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshAdmin.Domain, AshJsonApi.Domain, AshTypescript.Rpc]

  admin do
    show? true
  end

  typescript_rpc do
    resource Angle.Catalog.Category do
      rpc_action :list_categories, :read
      rpc_action :create_category, :create
    end
  end

  resources do
    resource Angle.Catalog.Category
    resource Angle.Catalog.OptionSet
    resource Angle.Catalog.OptionSetValue
  end
end
