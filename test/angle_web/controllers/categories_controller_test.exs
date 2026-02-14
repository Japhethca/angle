defmodule AngleWeb.CategoriesControllerTest do
  use AngleWeb.ConnCase

  describe "GET /categories" do
    test "returns an Inertia response", %{conn: conn} do
      conn = get(conn, ~p"/categories")
      response = html_response(conn, 200)
      assert response =~ ~s(id="app")
      assert response =~ ~s(data-page=)
    end
  end

  describe "GET /categories/:slug" do
    test "returns an Inertia response for a valid parent category", %{conn: conn} do
      category = create_category(%{name: "Electronics", slug: "electronics"})
      _sub = create_category(%{name: "Phones", slug: "phones", parent_id: category.id})

      conn = get(conn, ~p"/categories/electronics")
      response = html_response(conn, 200)
      assert response =~ ~s(id="app")
      assert response =~ ~s(data-page=)
    end

    test "redirects to /categories when category not found", %{conn: conn} do
      conn = get(conn, ~p"/categories/nonexistent")
      assert redirected_to(conn) == "/categories"
    end
  end

  describe "GET /categories/:slug/:sub_slug" do
    test "returns an Inertia response for a valid subcategory", %{conn: conn} do
      parent = create_category(%{name: "Electronics", slug: "electronics"})
      _sub = create_category(%{name: "Phones", slug: "phones", parent_id: parent.id})

      conn = get(conn, ~p"/categories/electronics/phones")
      response = html_response(conn, 200)
      assert response =~ ~s(id="app")
      assert response =~ ~s(data-page=)
    end

    test "redirects to parent when subcategory not found", %{conn: conn} do
      _parent = create_category(%{name: "Electronics", slug: "electronics"})

      conn = get(conn, ~p"/categories/electronics/nonexistent")
      assert redirected_to(conn) == "/categories/electronics"
    end
  end
end
