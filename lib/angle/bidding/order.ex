defmodule Angle.Bidding.Order do
  @moduledoc "Represents an order created when a buyer wins an auction."

  use Ash.Resource,
    domain: Angle.Bidding,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  require Ash.Resource.Validation.Builtins

  postgres do
    table "orders"
    repo Angle.Repo
  end

  typescript do
    type_name "Order"
  end

  actions do
    defaults []

    create :create do
      accept [:amount, :item_id]
      argument :buyer_id, :uuid, allow_nil?: false
      argument :seller_id, :uuid, allow_nil?: false
      change set_attribute(:buyer_id, arg(:buyer_id))
      change set_attribute(:seller_id, arg(:seller_id))
      change set_attribute(:status, :payment_pending)
    end

    read :read do
      primary? true
      pagination offset?: true, required?: false
    end

    read :buyer_orders do
      description "List orders for the current buyer"
      filter expr(buyer_id == ^actor(:id))
      pagination offset?: true, required?: false
    end

    read :seller_orders do
      description "List orders for the current seller"
      filter expr(seller_id == ^actor(:id))
      prepare build(sort: [created_at: :desc])
      pagination offset?: true, required?: false
    end

    update :pay_order do
      accept []
      argument :payment_reference, :string, allow_nil?: false

      validate attribute_equals(:status, :payment_pending),
        message: "Order must be in payment_pending status to pay"

      change set_attribute(:status, :paid)
      change set_attribute(:payment_reference, arg(:payment_reference))
      change set_attribute(:paid_at, &DateTime.utc_now/0)
    end

    update :mark_dispatched do
      accept []

      validate attribute_equals(:status, :paid),
        message: "Order must be in paid status to dispatch"

      change set_attribute(:status, :dispatched)
      change set_attribute(:dispatched_at, &DateTime.utc_now/0)
    end

    update :confirm_receipt do
      accept []

      validate attribute_equals(:status, :dispatched),
        message: "Order must be in dispatched status to confirm receipt"

      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action(:create) do
      authorize_if always()
    end

    policy action(:read) do
      authorize_if expr(buyer_id == ^actor(:id))
      authorize_if expr(seller_id == ^actor(:id))
    end

    policy action(:buyer_orders) do
      authorize_if always()
    end

    policy action(:seller_orders) do
      authorize_if always()
    end

    policy action(:pay_order) do
      authorize_if expr(buyer_id == ^actor(:id))
    end

    policy action(:mark_dispatched) do
      authorize_if expr(seller_id == ^actor(:id))
    end

    policy action(:confirm_receipt) do
      authorize_if expr(buyer_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, Angle.Bidding.Order.OrderStatus do
      allow_nil? false
      public? true
      default :payment_pending
    end

    attribute :amount, :decimal do
      allow_nil? false
      public? true
    end

    attribute :payment_reference, :string do
      public? true
    end

    attribute :paid_at, :utc_datetime_usec do
      public? true
    end

    attribute :dispatched_at, :utc_datetime_usec do
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :created_at, public?: true
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :item, Angle.Inventory.Item do
      allow_nil? false
      public? true
    end

    belongs_to :buyer, Angle.Accounts.User do
      allow_nil? false
      public? true
    end

    belongs_to :seller, Angle.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  identities do
    # Note: prevents same buyer winning relisted item. Remove if items can be relisted.
    identity :unique_item_buyer, [:item_id, :buyer_id]
  end
end
