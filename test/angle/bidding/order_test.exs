defmodule Angle.Bidding.OrderTest do
  use Angle.DataCase, async: true
  import Angle.Factory

  describe "seller_orders" do
    test "returns orders where user is the seller" do
      seller = create_user()
      buyer = create_user()
      other_seller = create_user()

      item1 = create_item(%{created_by_id: seller.id})
      item2 = create_item(%{created_by_id: other_seller.id})

      order1 = create_order(%{buyer: buyer, seller: seller, item: item1})
      _order2 = create_order(%{buyer: buyer, seller: other_seller, item: item2})

      results =
        Angle.Bidding.Order
        |> Ash.Query.for_read(:seller_orders, %{}, actor: seller)
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).id == order1.id
    end
  end

  describe "order lifecycle" do
    setup do
      buyer = create_user()
      seller = create_user()
      item = create_item(%{created_by_id: seller.id, starting_price: Decimal.new("100.00")})

      order =
        create_order(%{
          buyer: buyer,
          seller: seller,
          item: item,
          amount: Decimal.new("150.00")
        })

      %{buyer: buyer, seller: seller, item: item, order: order}
    end

    test "creates order with payment_pending status", %{order: order} do
      assert order.status == :payment_pending
      assert Decimal.equal?(order.amount, Decimal.new("150.00"))
    end

    test "pay_order transitions to paid", %{order: order, buyer: buyer} do
      assert {:ok, paid_order} =
               order
               |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_123"},
                 actor: buyer,
                 authorize?: false
               )
               |> Ash.update(authorize?: false)

      assert paid_order.status == :paid
      assert paid_order.payment_reference == "PSK_ref_123"
      assert paid_order.paid_at != nil
    end

    test "mark_dispatched transitions from paid to dispatched", %{
      order: order,
      buyer: buyer,
      seller: seller
    } do
      {:ok, paid_order} =
        order
        |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_123"},
          actor: buyer,
          authorize?: false
        )
        |> Ash.update(authorize?: false)

      assert {:ok, dispatched_order} =
               paid_order
               |> Ash.Changeset.for_update(:mark_dispatched, %{},
                 actor: seller,
                 authorize?: false
               )
               |> Ash.update(authorize?: false)

      assert dispatched_order.status == :dispatched
      assert dispatched_order.dispatched_at != nil
    end

    test "confirm_receipt transitions from dispatched to completed", %{
      order: order,
      buyer: buyer,
      seller: seller
    } do
      {:ok, paid_order} =
        order
        |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_123"},
          actor: buyer,
          authorize?: false
        )
        |> Ash.update(authorize?: false)

      {:ok, dispatched_order} =
        paid_order
        |> Ash.Changeset.for_update(:mark_dispatched, %{},
          actor: seller,
          authorize?: false
        )
        |> Ash.update(authorize?: false)

      assert {:ok, completed_order} =
               dispatched_order
               |> Ash.Changeset.for_update(:confirm_receipt, %{},
                 actor: buyer,
                 authorize?: false
               )
               |> Ash.update(authorize?: false)

      assert completed_order.status == :completed
      assert completed_order.completed_at != nil
    end

    test "cannot pay an already paid order", %{order: order, buyer: buyer} do
      {:ok, paid_order} =
        order
        |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_123"},
          actor: buyer,
          authorize?: false
        )
        |> Ash.update(authorize?: false)

      assert {:error, _} =
               paid_order
               |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_456"},
                 actor: buyer,
                 authorize?: false
               )
               |> Ash.update(authorize?: false)
    end

    test "cannot dispatch order that hasn't been paid", %{order: order, seller: seller} do
      assert {:error, _} =
               order
               |> Ash.Changeset.for_update(:mark_dispatched, %{},
                 actor: seller,
                 authorize?: false
               )
               |> Ash.update(authorize?: false)
    end

    test "cannot confirm receipt without dispatch", %{order: order, buyer: buyer} do
      {:ok, paid_order} =
        order
        |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_123"},
          actor: buyer,
          authorize?: false
        )
        |> Ash.update(authorize?: false)

      assert {:error, _} =
               paid_order
               |> Ash.Changeset.for_update(:confirm_receipt, %{},
                 actor: buyer,
                 authorize?: false
               )
               |> Ash.update(authorize?: false)
    end
  end

  describe "authorization policies" do
    setup do
      buyer = create_user()
      seller = create_user()
      other_user = create_user()
      item = create_item(%{created_by_id: seller.id, starting_price: Decimal.new("100.00")})

      order =
        create_order(%{
          buyer: buyer,
          seller: seller,
          item: item,
          amount: Decimal.new("150.00")
        })

      %{buyer: buyer, seller: seller, other_user: other_user, item: item, order: order}
    end

    test "buyer can read their own order", %{order: order, buyer: buyer} do
      assert {:ok, _} = Ash.get(Angle.Bidding.Order, order.id, actor: buyer)
    end

    test "seller can read order for their item", %{order: order, seller: seller} do
      assert {:ok, _} = Ash.get(Angle.Bidding.Order, order.id, actor: seller)
    end

    test "other user cannot read someone else's order", %{order: order, other_user: other_user} do
      # Ash read policies filter rather than forbid, so unauthorized reads return NotFound
      assert {:error, %Ash.Error.Invalid{}} =
               Ash.get(Angle.Bidding.Order, order.id, actor: other_user)
    end

    test "seller cannot pay_order", %{order: order, seller: seller} do
      assert {:error, %Ash.Error.Forbidden{}} =
               order
               |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_123"},
                 actor: seller
               )
               |> Ash.update()
    end

    test "buyer cannot mark_dispatched", %{order: order, buyer: buyer, seller: seller} do
      {:ok, paid_order} =
        order
        |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_123"}, actor: buyer)
        |> Ash.update()

      assert {:error, %Ash.Error.Forbidden{}} =
               paid_order
               |> Ash.Changeset.for_update(:mark_dispatched, %{}, actor: buyer)
               |> Ash.update()

      # seller can mark dispatched
      assert {:ok, _} =
               paid_order
               |> Ash.Changeset.for_update(:mark_dispatched, %{}, actor: seller)
               |> Ash.update()
    end

    test "seller cannot confirm_receipt", %{order: order, buyer: buyer, seller: seller} do
      {:ok, paid_order} =
        order
        |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_123"}, actor: buyer)
        |> Ash.update()

      {:ok, dispatched_order} =
        paid_order
        |> Ash.Changeset.for_update(:mark_dispatched, %{}, actor: seller)
        |> Ash.update()

      assert {:error, %Ash.Error.Forbidden{}} =
               dispatched_order
               |> Ash.Changeset.for_update(:confirm_receipt, %{}, actor: seller)
               |> Ash.update()

      # buyer can confirm receipt
      assert {:ok, _} =
               dispatched_order
               |> Ash.Changeset.for_update(:confirm_receipt, %{}, actor: buyer)
               |> Ash.update()
    end
  end
end
