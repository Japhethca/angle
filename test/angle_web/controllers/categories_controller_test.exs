defmodule AngleWeb.CategoriesControllerTest do
  use AngleWeb.ConnCase

  # Helper to generate unique slugs to avoid conflicts in parallel tests
  defp unique_slug(base \\ "electronics") do
    "#{base}-#{System.unique_integer([:positive])}"
  end

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
      slug = unique_slug()
      category = create_category(%{name: "Electronics", slug: slug})
      _sub = create_category(%{name: "Phones", slug: "phones-#{slug}", parent_id: category.id})

      conn = get(conn, ~p"/categories/#{slug}")
      response = html_response(conn, 200)
      assert response =~ "categories/show"
      assert response =~ "Electronics"
      assert response =~ "Phones"
    end

    test "includes published items in the response", %{conn: conn} do
      slug = unique_slug()
      category = create_category(%{name: "Electronics", slug: slug})
      user = create_user()

      item =
        create_item(%{
          title: "Published Widget",
          category_id: category.id,
          created_by_id: user.id
        })

      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/categories/#{slug}")
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
      slug = unique_slug()
      parent = create_category(%{name: "Electronics", slug: slug})
      sub_slug = "phones-#{slug}"
      _sub = create_category(%{name: "Phones", slug: sub_slug, parent_id: parent.id})

      conn = get(conn, ~p"/categories/#{slug}/#{sub_slug}")
      response = html_response(conn, 200)
      assert response =~ "categories/show"
      assert response =~ "Electronics"
      assert response =~ "Phones"
    end

    test "shows only subcategory items when filtering", %{conn: conn} do
      slug = unique_slug()
      parent = create_category(%{name: "Electronics", slug: slug})
      sub_slug = "phones-#{slug}"
      sub = create_category(%{name: "Phones", slug: sub_slug, parent_id: parent.id})
      user = create_user()

      item =
        create_item(%{
          title: "Phone Item",
          category_id: sub.id,
          created_by_id: user.id
        })

      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/categories/#{slug}/#{sub_slug}")
      response = html_response(conn, 200)
      assert response =~ "Phone Item"
    end

    test "redirects to parent when subcategory not found", %{conn: conn} do
      slug = unique_slug()
      _parent = create_category(%{name: "Electronics", slug: slug})

      conn = get(conn, ~p"/categories/#{slug}/nonexistent")
      assert redirected_to(conn) == "/categories/#{slug}"
    end
  end
end
