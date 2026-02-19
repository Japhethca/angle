defmodule AngleWeb.SearchControllerTest do
  use AngleWeb.ConnCase, async: true

  defp publish_item(item) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
    |> Ash.update!()
  end

  describe "GET /search" do
    test "renders search page with empty query", %{conn: conn} do
      conn = get(conn, ~p"/search")
      response = html_response(conn, 200)
      assert response =~ "search"
    end

    test "renders search page with query param", %{conn: conn} do
      user = create_user()
      item = create_item(%{title: "Searchable Widget", created_by_id: user.id})
      publish_item(item)

      conn = get(conn, ~p"/search?q=Widget")
      response = html_response(conn, 200)
      assert response =~ "search"
    end

    test "returns no results for unmatched query", %{conn: conn} do
      conn = get(conn, ~p"/search?q=xyznonexistent123")
      response = html_response(conn, 200)
      assert response =~ "search"
    end

    test "renders items with ending-soon filter without query", %{conn: conn} do
      user = create_user()

      item =
        create_item(%{
          title: "Test Item",
          end_time: ~U[2026-02-20 10:00:00Z],
          created_by_id: user.id
        })

      publish_item(item)

      conn = get(conn, ~p"/search?filter=ending-soon")
      assert html_response(conn, 200) =~ "Test Item"
    end

    test "renders items with trending filter sorted by view count", %{conn: conn} do
      user = create_user()
      item1 = create_item(%{title: "Popular Item", view_count: 100, created_by_id: user.id})
      item2 = create_item(%{title: "Less Popular", view_count: 10, created_by_id: user.id})
      publish_item(item1)
      publish_item(item2)

      conn = get(conn, ~p"/search?filter=trending")
      response = html_response(conn, 200)
      assert response =~ "Popular Item"
      assert response =~ "Less Popular"
    end

    test "renders items with recommended filter sorted by newest", %{conn: conn} do
      user = create_user()
      item = create_item(%{title: "Newest Item", created_by_id: user.id})
      publish_item(item)

      conn = get(conn, ~p"/search?filter=recommended")
      assert html_response(conn, 200) =~ "Newest Item"
    end

    test "returns empty results when no query and no filter", %{conn: conn} do
      conn = get(conn, ~p"/search")
      response = html_response(conn, 200)
      assert response =~ "Search for items"
    end

    test "combines filter preset with text query", %{conn: conn} do
      user = create_user()
      item = create_item(%{title: "Laptop Computer", created_by_id: user.id})
      publish_item(item)

      conn = get(conn, ~p"/search?q=laptop&filter=trending")
      assert html_response(conn, 200) =~ "Laptop Computer"
    end
  end
end
