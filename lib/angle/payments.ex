defmodule Angle.Payments do
  use Ash.Domain,
    otp_app: :angle

  resources do
    resource Angle.Payments.UserWallet do
      define :create_wallet, action: :create
      define :get_wallet, action: :read, get_by: [:user_id]
      define :deposit_to_wallet, action: :deposit, args: [:amount]
      define :withdraw_from_wallet, action: :withdraw, args: [:amount]

      define :check_wallet_balance,
        action: :check_minimum_balance,
        args: [:required_amount],
        get_by: [:id]
    end

    resource Angle.Payments.WalletTransaction do
      define :create_transaction, action: :create
      define :list_transactions, action: :read
    end

    resource Angle.Payments.PaymentMethod do
      define :get_payment_method, action: :read, get_by: [:id]
      define :list_payment_methods, action: :list_by_user
      define :create_payment_method, action: :create
      define :destroy_payment_method, action: :destroy
    end

    resource Angle.Payments.PayoutMethod do
      define :get_payout_method, action: :read, get_by: [:id]
      define :list_payout_methods, action: :list_by_user
      define :create_payout_method, action: :create
      define :destroy_payout_method, action: :destroy
    end
  end
end
