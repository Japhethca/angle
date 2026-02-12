defmodule Angle.Accounts do
  use Ash.Domain, otp_app: :angle, extensions: [AshAdmin.Domain, AshTypescript.Rpc]

  admin do
    show? true
  end

  typescript_rpc do
    resource Angle.Accounts.User do
      rpc_action :list_users, :read
    end
  end

  resources do
    resource Angle.Accounts.Token
    resource Angle.Accounts.User
    resource Angle.Accounts.UserRole
    resource Angle.Accounts.Role
    resource Angle.Accounts.Permission
    resource Angle.Accounts.RolePermission
  end
end
