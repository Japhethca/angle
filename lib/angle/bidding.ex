defmodule Angle.Bidding do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshAdmin.Domain, AshGraphql.Domain, AshJsonApi.Domain, AshTypescript.Rpc]

  admin do
    show? true
  end

  typescript_rpc do
    resource Angle.Bidding.Bid do
      rpc_action :list_bids, :read
      rpc_action :make_bid, :make_bid

      # Active tab: user's bids on active items
      typed_query :active_bid_card, :read do
        ts_result_type_name "ActiveBidCard"
        ts_fields_const_name "activeBidCardFields"

        fields [
          :id,
          :amount,
          :bid_type,
          :bid_time,
          :item_id,
          :user_id,
          %{
            item: [
              :id,
              :title,
              :slug,
              :current_price,
              :starting_price,
              :end_time,
              :auction_status,
              :bid_count,
              :watcher_count
            ]
          }
        ]
      end

      # History tab: user's past bids
      typed_query :history_bid_card, :read do
        ts_result_type_name "HistoryBidCard"
        ts_fields_const_name "historyBidCardFields"

        fields [
          :id,
          :amount,
          :bid_time,
          :item_id,
          :user_id,
          %{
            item: [
              :id,
              :title,
              :slug,
              :auction_status,
              :created_by_id,
              %{
                user: [
                  :id,
                  :username,
                  :full_name
                ]
              }
            ]
          }
        ]
      end
    end

    resource Angle.Bidding.Order do
      rpc_action :list_orders, :buyer_orders
      rpc_action :pay_order, :pay_order
      rpc_action :mark_dispatched, :mark_dispatched
      rpc_action :confirm_receipt, :confirm_receipt

      # Won tab: user's orders
      typed_query :won_order_card, :buyer_orders do
        ts_result_type_name "WonOrderCard"
        ts_fields_const_name "wonOrderCardFields"

        fields [
          :id,
          :status,
          :amount,
          :payment_reference,
          :paid_at,
          :dispatched_at,
          :completed_at,
          :created_at,
          %{
            item: [
              :id,
              :title,
              :slug
            ]
          },
          %{
            seller: [
              :id,
              :username,
              :full_name,
              :whatsapp_number
            ]
          }
        ]
      end

      rpc_action :list_seller_orders, :seller_orders

      typed_query :seller_payment_card, :seller_orders do
        ts_result_type_name "SellerPaymentCard"
        ts_fields_const_name "sellerPaymentCardFields"

        fields [
          :id,
          :status,
          :amount,
          :payment_reference,
          :created_at,
          %{
            item: [
              :id,
              :title
            ]
          }
        ]
      end
    end

    resource Angle.Bidding.Review do
      rpc_action :create_review, :create
      rpc_action :update_review, :update
      rpc_action :list_reviews_by_seller, :by_seller
      rpc_action :get_review_for_order, :for_order

      typed_query :seller_review_card, :by_seller do
        ts_result_type_name "SellerReviewCard"
        ts_fields_const_name "sellerReviewCardFields"

        fields [
          :id,
          :rating,
          :comment,
          :inserted_at,
          %{
            reviewer: [
              :id,
              :username,
              :full_name
            ]
          }
        ]
      end
    end
  end

  resources do
    resource Angle.Bidding.Bid
    resource Angle.Bidding.Order
    resource Angle.Bidding.Review
  end
end
