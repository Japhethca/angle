defmodule Angle.Bidding.OrderTest do
  use Angle.DataCase, async: true
  import Angle.Factory

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
end
