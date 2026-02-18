defmodule AngleWeb.ItemsControllerTest do
  use AngleWeb.ConnCase, async: true

  describe "GET /store/listings/new" do
    test "returns 200 for authenticated user with store profile", %{conn: conn} do
      user = create_user()
      create_store_profile(%{user_id: user.id, delivery_preference: "seller_delivers"})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings/new")

      assert html_response(conn, 200) =~ "store/listings/new"
    end

    test "returns 200 for authenticated user without store profile", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings/new")

      assert html_response(conn, 200) =~ "store/listings/new"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/store/listings/new")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end
end
