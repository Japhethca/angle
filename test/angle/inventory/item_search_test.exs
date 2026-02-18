defmodule Angle.Inventory.ItemSearchTest do
  use Angle.DataCase, async: true

  import Angle.Factory

  describe "search action" do
    setup do
      user = create_user()

      category =
        create_category(%{
          name: "Electronics",
          slug: "electronics-#{System.unique_integer([:positive])}"
        })

      item1 =
        create_item(%{
          title: "iPhone 15 Pro Max",
          description: "Latest Apple smartphone with titanium frame",
          created_by_id: user.id,
          category_id: category.id,
          condition: :new,
          sale_type: :auction
        })

      publish_item(item1, user)

      item2 =
        create_item(%{
          title: "Samsung Galaxy S24 Ultra",
          description: "Flagship Android phone with S Pen",
          created_by_id: user.id,
          category_id: category.id,
          condition: :used,
          sale_type: :buy_now
        })

      publish_item(item2, user)

      item3 =
        create_item(%{
          title: "Vintage Rolex Watch",
          description: "Classic luxury timepiece from the 1960s",
          created_by_id: user.id,
          condition: :used,
          sale_type: :auction
        })

      publish_item(item3, user)

      # Draft item -- should NOT appear in search
      _draft =
        create_item(%{
          title: "Draft iPhone Case",
          description: "Unpublished item",
          created_by_id: user.id
        })

      %{user: user, category: category, item1: item1, item2: item2, item3: item3}
    end

    test "finds items by title keyword", %{item1: item1} do
      results = search_items("iPhone")
      assert Enum.any?(results, &(&1.id == item1.id))
    end

    test "finds items by description keyword", %{item1: item1} do
      results = search_items("titanium")
      assert Enum.any?(results, &(&1.id == item1.id))
    end

    test "does not return draft items" do
      results = search_items("Draft")
      assert results == []
    end

    test "fuzzy matches typos via trigram", %{item1: item1} do
      results = search_items("iphon")
      assert Enum.any?(results, &(&1.id == item1.id))
    end

    test "filters by category", %{item1: item1, item2: item2, item3: item3, category: category} do
      results = search_items("phone", %{category_id: category.id})
      ids = Enum.map(results, & &1.id)
      # item1 (iPhone) and item2 (phone in description) should match
      assert item1.id in ids or item2.id in ids
      refute item3.id in ids
    end

    test "filters by condition", %{item2: item2} do
      results = search_items("Samsung", %{condition: :used})
      assert Enum.any?(results, &(&1.id == item2.id))
    end

    test "price range filter returns no results when current_price is nil", %{item1: item1} do
      # Factory items have nil current_price, so min_price filter excludes them
      results = search_items("iPhone", %{min_price: "1.00"})
      refute Enum.any?(results, &(&1.id == item1.id))
    end

    test "price range filter with only max_price excludes nil current_price", %{item1: item1} do
      results = search_items("iPhone", %{max_price: "100.00"})
      refute Enum.any?(results, &(&1.id == item1.id))
    end

    test "returns empty for unmatched query" do
      results = search_items("xyznonexistent123")
      assert results == []
    end

    test "pagination works" do
      results = search_items("item", %{}, %{limit: 1, offset: 0})
      assert length(results) <= 1
    end
  end

  defp search_items(query, filters \\ %{}, page \\ %{}) do
    args = Map.merge(%{query: query}, filters)

    Angle.Inventory.Item
    |> Ash.Query.for_read(:search, args, authorize?: false)
    |> then(fn q ->
      case page do
        %{limit: _} ->
          %Ash.Page.Offset{results: results} =
            Ash.read!(q, page: [limit: page[:limit], offset: page[:offset] || 0])

          results

        _ ->
          Ash.read!(q)
      end
    end)
  end

  defp publish_item(item, user) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, actor: user, authorize?: false)
    |> Ash.update!()
  end
end
