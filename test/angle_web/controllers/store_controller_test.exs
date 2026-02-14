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
