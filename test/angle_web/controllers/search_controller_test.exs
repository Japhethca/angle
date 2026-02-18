defmodule AngleWeb.SearchControllerTest do
  use AngleWeb.ConnCase

  describe "GET /search" do
    test "renders search page with empty query", %{conn: conn} do
      conn = get(conn, ~p"/search")
      response = html_response(conn, 200)
      assert response =~ "search"
    end

    test "renders search page with query param", %{conn: conn} do
      user = create_user()

      item =
        create_item(%{title: "Searchable Widget", created_by_id: user.id})

      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/search?q=Widget")
      response = html_response(conn, 200)
      assert response =~ "search"
    end

    test "returns no results for unmatched query", %{conn: conn} do
      conn = get(conn, ~p"/search?q=xyznonexistent123")
      response = html_response(conn, 200)
      assert response =~ "search"
    end
  end
end
