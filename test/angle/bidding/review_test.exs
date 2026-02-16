defmodule Angle.Bidding.ReviewTest do
  use Angle.DataCase, async: true

  describe "create" do
    test "buyer can review a completed order" do
      buyer = create_user()
      seller = create_user()
      item = create_item(%{created_by_id: seller.id})
      order = create_order(%{buyer: buyer, seller: seller, item: item})

      order = complete_order(order)

      review =
        Angle.Bidding.Review
        |> Ash.Changeset.for_create(
          :create,
          %{order_id: order.id, rating: 5, comment: "Great seller!"},
          actor: buyer
        )
        |> Ash.create!()

      assert review.rating == 5
      assert review.comment == "Great seller!"
      assert review.reviewer_id == buyer.id
      assert review.seller_id == seller.id
      assert review.order_id == order.id
    end

    test "rejects review for non-completed order" do
      buyer = create_user()
      seller = create_user()
      item = create_item(%{created_by_id: seller.id})
      order = create_order(%{buyer: buyer, seller: seller, item: item})

      assert {:error, _} =
               Angle.Bidding.Review
               |> Ash.Changeset.for_create(:create, %{order_id: order.id, rating: 4},
                 actor: buyer
               )
               |> Ash.create()
    end

    test "rejects duplicate review for same order" do
      buyer = create_user()
      seller = create_user()
      item = create_item(%{created_by_id: seller.id})
      order = create_order(%{buyer: buyer, seller: seller, item: item})

      order = complete_order(order)

      Angle.Bidding.Review
      |> Ash.Changeset.for_create(:create, %{order_id: order.id, rating: 5}, actor: buyer)
      |> Ash.create!()

      assert {:error, _} =
               Angle.Bidding.Review
               |> Ash.Changeset.for_create(:create, %{order_id: order.id, rating: 3},
                 actor: buyer
               )
               |> Ash.create()
    end

    test "rejects review from non-buyer" do
      buyer = create_user()
      seller = create_user()
      stranger = create_user()
      item = create_item(%{created_by_id: seller.id})
      order = create_order(%{buyer: buyer, seller: seller, item: item})

      order = complete_order(order)

      assert {:error, _} =
               Angle.Bidding.Review
               |> Ash.Changeset.for_create(:create, %{order_id: order.id, rating: 5},
                 actor: stranger
               )
               |> Ash.create()
    end

    test "rejects rating outside 1-5" do
      buyer = create_user()
      seller = create_user()
      item = create_item(%{created_by_id: seller.id})
      order = create_order(%{buyer: buyer, seller: seller, item: item})

      order = complete_order(order)

      assert {:error, _} =
               Angle.Bidding.Review
               |> Ash.Changeset.for_create(:create, %{order_id: order.id, rating: 0},
                 actor: buyer
               )
               |> Ash.create()

      assert {:error, _} =
               Angle.Bidding.Review
               |> Ash.Changeset.for_create(:create, %{order_id: order.id, rating: 6},
                 actor: buyer
               )
               |> Ash.create()
    end
  end

  describe "update" do
    test "reviewer can edit their review within 7 days" do
      buyer = create_user()
      seller = create_user()
      item = create_item(%{created_by_id: seller.id})
      order = create_order(%{buyer: buyer, seller: seller, item: item})
      order = complete_order(order)

      review =
        Angle.Bidding.Review
        |> Ash.Changeset.for_create(:create, %{order_id: order.id, rating: 3, comment: "OK"},
          actor: buyer
        )
        |> Ash.create!()

      updated =
        review
        |> Ash.Changeset.for_update(:update, %{rating: 5, comment: "Actually great!"},
          actor: buyer
        )
        |> Ash.update!()

      assert updated.rating == 5
      assert updated.comment == "Actually great!"
    end

    test "non-reviewer cannot edit the review" do
      buyer = create_user()
      seller = create_user()
      item = create_item(%{created_by_id: seller.id})
      order = create_order(%{buyer: buyer, seller: seller, item: item})
      order = complete_order(order)

      review =
        Angle.Bidding.Review
        |> Ash.Changeset.for_create(:create, %{order_id: order.id, rating: 3}, actor: buyer)
        |> Ash.create!()

      assert {:error, _} =
               review
               |> Ash.Changeset.for_update(:update, %{rating: 1}, actor: seller)
               |> Ash.update()
    end
  end

  describe "by_seller" do
    test "returns reviews for a specific seller" do
      buyer1 = create_user()
      buyer2 = create_user()
      seller = create_user()
      other_seller = create_user()

      item1 = create_item(%{created_by_id: seller.id})
      item2 = create_item(%{created_by_id: seller.id})
      item3 = create_item(%{created_by_id: other_seller.id})

      order1 = create_order(%{buyer: buyer1, seller: seller, item: item1}) |> complete_order()
      order2 = create_order(%{buyer: buyer2, seller: seller, item: item2}) |> complete_order()

      order3 =
        create_order(%{buyer: buyer1, seller: other_seller, item: item3}) |> complete_order()

      Angle.Bidding.Review
      |> Ash.Changeset.for_create(:create, %{order_id: order1.id, rating: 5}, actor: buyer1)
      |> Ash.create!()

      Angle.Bidding.Review
      |> Ash.Changeset.for_create(:create, %{order_id: order2.id, rating: 4}, actor: buyer2)
      |> Ash.create!()

      Angle.Bidding.Review
      |> Ash.Changeset.for_create(:create, %{order_id: order3.id, rating: 2}, actor: buyer1)
      |> Ash.create!()

      results =
        Angle.Bidding.Review
        |> Ash.Query.for_read(:by_seller, %{seller_id: seller.id})
        |> Ash.read!()

      assert length(results) == 2
    end
  end

  describe "for_order" do
    test "returns review for a specific order" do
      buyer = create_user()
      seller = create_user()
      item = create_item(%{created_by_id: seller.id})
      order = create_order(%{buyer: buyer, seller: seller, item: item}) |> complete_order()

      Angle.Bidding.Review
      |> Ash.Changeset.for_create(:create, %{order_id: order.id, rating: 5}, actor: buyer)
      |> Ash.create!()

      results =
        Angle.Bidding.Review
        |> Ash.Query.for_read(:for_order, %{order_id: order.id})
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).order_id == order.id
    end
  end

  defp complete_order(order) do
    order
    |> Ash.Changeset.for_update(
      :pay_order,
      %{payment_reference: "PAY_#{System.unique_integer([:positive])}"},
      authorize?: false
    )
    |> Ash.update!()
    |> Ash.Changeset.for_update(:mark_dispatched, %{}, authorize?: false)
    |> Ash.update!()
    |> Ash.Changeset.for_update(:confirm_receipt, %{}, authorize?: false)
    |> Ash.update!()
  end
end
