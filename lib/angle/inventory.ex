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

      typed_query :homepage_item_card, :read do
        ts_result_type_name "HomepageItemCard"
        ts_fields_const_name "homepageItemCardFields"

        fields [
          :id,
          :title,
          :slug,
          :starting_price,
          :current_price,
          :end_time,
          :auction_status,
          :condition,
          :sale_type,
          :view_count,
          %{category: [:id, :name, :slug]}
        ]
      end

      typed_query :category_item_card, :by_category do
        ts_result_type_name "CategoryItemCard"
        ts_fields_const_name "categoryItemCardFields"

        fields [
          :id,
          :title,
          :slug,
          :starting_price,
          :current_price,
          :end_time,
          :auction_status,
          :condition,
          :sale_type,
          :view_count,
          :bid_count,
          %{category: [:id, :name, :slug]}
        ]
      end

      typed_query :seller_item_card, :by_seller do
        ts_result_type_name "SellerItemCard"
        ts_fields_const_name "sellerItemCardFields"

        fields [
          :id,
          :title,
          :slug,
          :starting_price,
          :current_price,
          :end_time,
          :auction_status,
          :condition,
          :sale_type,
          :view_count,
          :bid_count,
          %{category: [:id, :name, :slug]}
        ]
      end

      typed_query :item_detail, :read do
        ts_result_type_name "ItemDetail"
        ts_fields_const_name "itemDetailFields"

        fields [
          :id,
          :title,
          :description,
          :slug,
          :starting_price,
          :current_price,
          :reserve_price,
          :bid_increment,
          :buy_now_price,
          :end_time,
          :start_time,
          :auction_status,
          :publication_status,
          :condition,
          :sale_type,
          :auction_format,
          :view_count,
          :location,
          :attributes,
          :lot_number,
          :created_by_id,
          :bid_count,
          %{category: [:id, :name, :slug]},
          %{user: [:id, :email, :full_name, :username]}
        ]
      end
    end
  end

  resources do
    resource Angle.Inventory.Item
    resource Angle.Inventory.ItemActivity
  end
end
