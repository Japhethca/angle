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
      rpc_action :update_auto_charge, :update_auto_charge
      rpc_action :update_notification_preferences, :update_notification_preferences
      rpc_action :change_password, :change_password

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
          :avg_rating,
          :review_count,
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

    resource Angle.Accounts.User do
      define :get_user, action: :read, get_by: [:id]
      define :confirm_user, action: :confirm
      define :get_by_subject
      define :change_password
      define :sign_in_with_password
      define :sign_in_with_token
      define :register_with_password
      define :request_password_reset_token
      define :request_password_reset_with_password
      define :password_reset_with_password
      define :get_by_email
      define :assign_role
      define :remove_role
    end

    resource Angle.Accounts.UserRole
    resource Angle.Accounts.Role
    resource Angle.Accounts.Permission
    resource Angle.Accounts.RolePermission
    resource Angle.Accounts.Otp

    resource Angle.Accounts.StoreProfile do
      define :get_store_profile_by_user, action: :read, get_by: [:user_id]
      define :get_store_profile, action: :read, get_by: [:id]
    end
  end
end
