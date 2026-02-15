defmodule Angle.Accounts do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshAdmin.Domain, AshGraphql.Domain, AshTypescript.Rpc]

  admin do
    show? true
  end

  typescript_rpc do
    resource Angle.Accounts.User do
      rpc_action :list_users, :read
      rpc_action :update_profile, :update_profile

      typed_query :seller_profile, :read_public_profile do
        ts_result_type_name "SellerProfile"
        ts_fields_const_name "sellerProfileFields"

        fields [
          :id,
          :username,
          :full_name,
          :location,
          :phone_number,
          :whatsapp_number,
          :created_at,
          :published_item_count,
          store_profile: [
            :store_name,
            :location,
            :contact_phone,
            :whatsapp_link,
            :delivery_preference
          ]
        ]
      end
    end

    resource Angle.Accounts.StoreProfile do
      rpc_action :upsert_store_profile, :upsert
    end
  end

  resources do
    resource Angle.Accounts.Token
    resource Angle.Accounts.User
    resource Angle.Accounts.UserRole
    resource Angle.Accounts.Role
    resource Angle.Accounts.Permission
    resource Angle.Accounts.RolePermission
    resource Angle.Accounts.Otp
    resource Angle.Accounts.StoreProfile
  end
end
