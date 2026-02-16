defmodule Angle.Bidding.OrderTest do
  use Angle.DataCase, async: true

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
end
