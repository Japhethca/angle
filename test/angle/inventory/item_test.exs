defmodule Angle.Inventory.ItemTest do
  use Angle.DataCase, async: true

  describe "my_listings" do
    test "returns all items owned by the current user regardless of status" do
      seller = create_user()
      other = create_user()

      item1 = create_item(%{created_by_id: seller.id})
      _item2 = create_item(%{created_by_id: other.id})

      results =
        Angle.Inventory.Item
        |> Ash.Query.for_read(:my_listings, %{}, actor: seller)
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).id == item1.id
    end
  end
end
