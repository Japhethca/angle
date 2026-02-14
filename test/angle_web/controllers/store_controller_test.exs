defmodule AngleWeb.StoreControllerTest do
  use AngleWeb.ConnCase

  describe "GET /store/:identifier" do
    test "renders store/show page for a valid seller by username", %{conn: conn} do
      user = create_user(%{full_name: "Test Seller", username: "test-seller"})

      item =
        create_item(%{
          title: "Seller Widget",
          created_by_id: user.id
        })

      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/store/test-seller")
      response = html_response(conn, 200)
      assert response =~ "store/show"
      assert response =~ "Test Seller"
    end

    test "renders store/show page for a valid seller by UUID", %{conn: conn} do
      user = create_user(%{full_name: "UUID Seller"})

      item =
        create_item(%{
          title: "UUID Widget",
          created_by_id: user.id
        })

      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/store/#{user.id}")
      response = html_response(conn, 200)
      assert response =~ "store/show"
      assert response =~ "UUID Seller"
    end

    test "includes published items in the response", %{conn: conn} do
      user = create_user()

      item =
        create_item(%{
          title: "Published Store Item",
          created_by_id: user.id
        })

      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/store/#{user.id}")
      response = html_response(conn, 200)
      assert response =~ "Published Store Item"
    end

    test "does not include draft items in the response", %{conn: conn} do
      user = create_user()

      _draft =
        create_item(%{
          title: "Draft Secret Item",
          created_by_id: user.id
        })

      published =
        create_item(%{
          title: "Visible Item",
          created_by_id: user.id
        })

      Ash.update!(published, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/store/#{user.id}")
      response = html_response(conn, 200)
      assert response =~ "Visible Item"
      refute response =~ "Draft Secret Item"
    end

    test "respects ?tab=history query parameter", %{conn: conn} do
      user = create_user(%{full_name: "Tab Seller"})

      item =
        create_item(%{
          title: "Tab Item",
          created_by_id: user.id
        })

      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/store/#{user.id}?tab=history")
      response = html_response(conn, 200)
      assert response =~ "store/show"
      assert response =~ "&quot;active_tab&quot;:&quot;history&quot;"
    end

    test "defaults to auctions for invalid tab parameter", %{conn: conn} do
      user = create_user(%{full_name: "Invalid Tab Seller"})

      item =
        create_item(%{
          title: "Default Tab Item",
          created_by_id: user.id
        })

      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/store/#{user.id}?tab=invalid")
      response = html_response(conn, 200)
      assert response =~ "&quot;active_tab&quot;:&quot;auctions&quot;"
    end

    test "includes category summary for published items only", %{conn: conn} do
      user = create_user()
      cat_a = create_category(%{name: "Electronics", slug: "electronics"})
      cat_b = create_category(%{name: "Art", slug: "art"})

      # Two published items in Electronics
      for _ <- 1..2 do
        item = create_item(%{created_by_id: user.id, category_id: cat_a.id})
        Ash.update!(item, %{}, action: :publish_item, authorize?: false)
      end

      # One published item in Art
      art_item = create_item(%{created_by_id: user.id, category_id: cat_b.id})
      Ash.update!(art_item, %{}, action: :publish_item, authorize?: false)

      # One draft item in Art (should not count)
      _draft = create_item(%{created_by_id: user.id, category_id: cat_b.id})

      conn = get(conn, ~p"/store/#{user.id}")
      response = html_response(conn, 200)
      assert response =~ "Electronics"
      assert response =~ "Art"
    end

    test "excludes categories with no published items from summary", %{conn: conn} do
      user = create_user()
      _empty_cat = create_category(%{name: "Empty Category", slug: "empty-cat"})

      # Need at least one published item for the store page to render
      item = create_item(%{created_by_id: user.id})
      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/store/#{user.id}")
      response = html_response(conn, 200)
      refute response =~ "Empty Category"
    end

    test "redirects to / when seller not found", %{conn: conn} do
      conn = get(conn, ~p"/store/nonexistent-seller")
      assert redirected_to(conn) == "/"
    end

    test "redirects to / when UUID not found", %{conn: conn} do
      fake_uuid = Ecto.UUID.generate()
      conn = get(conn, ~p"/store/#{fake_uuid}")
      assert redirected_to(conn) == "/"
    end
  end
end
