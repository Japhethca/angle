defmodule Angle.Inventory do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshAdmin.Domain, AshGraphql.Domain, AshJsonApi.Domain, AshTypescript.Rpc]

  admin do
    show? true
  end

  typescript_rpc do
    resource Angle.Inventory.Item do
      rpc_action :list_items, :read
      rpc_action :create_draft_item, :create_draft
      rpc_action :update_draft_item, :update_draft
      rpc_action :publish_item, :publish_item
    end
  end

  resources do
    resource Angle.Inventory.Item
    resource Angle.Inventory.ItemActivity
  end
end
