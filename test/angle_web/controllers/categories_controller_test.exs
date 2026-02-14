defmodule AngleWeb.CategoriesControllerTest do
  use AngleWeb.ConnCase

  describe "GET /categories" do
    test "renders the categories/index Inertia page", %{conn: conn} do
      conn = get(conn, ~p"/categories")
      response = html_response(conn, 200)
      assert response =~ ~s(id="app")
      assert response =~ "categories/index"
    end

    test "includes seeded categories in the response", %{conn: conn} do
      create_category(%{name: "Test Gadgets", slug: "test-gadgets"})

      conn = get(conn, ~p"/categories")
      response = html_response(conn, 200)
      assert response =~ "Test Gadgets"
    end
  end

  describe "GET /categories/:slug" do
    test "renders the categories/show page with category and subcategories", %{conn: conn} do
      category = create_category(%{name: "Electronics", slug: "electronics"})
      _sub = create_category(%{name: "Phones", slug: "phones", parent_id: category.id})

      conn = get(conn, ~p"/categories/electronics")
      response = html_response(conn, 200)
      assert response =~ "categories/show"
      assert response =~ "Electronics"
      assert response =~ "Phones"
    end

    test "includes published items in the response", %{conn: conn} do
      category = create_category(%{name: "Electronics", slug: "electronics"})
      user = create_user()

      item =
        create_item(%{
          title: "Published Widget",
          category_id: category.id,
          created_by_id: user.id
        })

      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/categories/electronics")
      response = html_response(conn, 200)
      assert response =~ "Published Widget"
    end

    test "redirects to /categories when category not found", %{conn: conn} do
      conn = get(conn, ~p"/categories/nonexistent")
      assert redirected_to(conn) == "/categories"
    end
  end

  describe "GET /categories/:slug/:sub_slug" do
    test "renders the categories/show page for a valid subcategory", %{conn: conn} do
      parent = create_category(%{name: "Electronics", slug: "electronics"})
      _sub = create_category(%{name: "Phones", slug: "phones", parent_id: parent.id})

      conn = get(conn, ~p"/categories/electronics/phones")
      response = html_response(conn, 200)
      assert response =~ "categories/show"
      assert response =~ "Electronics"
      assert response =~ "Phones"
    end

    test "shows only subcategory items when filtering", %{conn: conn} do
      parent = create_category(%{name: "Electronics", slug: "electronics"})
      sub = create_category(%{name: "Phones", slug: "phones", parent_id: parent.id})
      user = create_user()

      item =
        create_item(%{
          title: "Phone Item",
          category_id: sub.id,
          created_by_id: user.id
        })

      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/categories/electronics/phones")
      response = html_response(conn, 200)
      assert response =~ "Phone Item"
    end

    test "redirects to parent when subcategory not found", %{conn: conn} do
      _parent = create_category(%{name: "Electronics", slug: "electronics"})

      conn = get(conn, ~p"/categories/electronics/nonexistent")
      assert redirected_to(conn) == "/categories/electronics"
    end
  end
end
