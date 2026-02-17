defmodule AngleWeb.StoreDashboardControllerTest do
  use AngleWeb.ConnCase, async: true

  describe "GET /store" do
    test "redirects to /store/listings", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store")

      assert redirected_to(conn) == ~p"/store/listings"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/store")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "GET /store/listings" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings")

      assert html_response(conn, 200) =~ "store/listings"
    end
  end

  describe "GET /store/payments" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/payments")

      assert html_response(conn, 200) =~ "store/payments"
    end
  end

  describe "GET /store/listings/:id/preview" do
    test "returns 200 for owner of draft item", %{conn: conn} do
      user = create_user()
      item = create_item(%{created_by_id: user.id})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings/#{item.id}/preview")

      assert html_response(conn, 200) =~ "store/listings/preview"
    end

    test "redirects when item not found", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings/#{Ecto.UUID.generate()}/preview")

      assert redirected_to(conn) == ~p"/store/listings"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/store/listings/#{Ecto.UUID.generate()}/preview")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "GET /store/listings/:id/edit" do
    test "returns 200 for owner of draft item", %{conn: conn} do
      user = create_user()
      item = create_item(%{created_by_id: user.id})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings/#{item.id}/edit?step=2")

      assert html_response(conn, 200) =~ "store/listings/edit"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/store/listings/#{Ecto.UUID.generate()}/edit")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "GET /store/profile" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/profile")

      assert html_response(conn, 200) =~ "store/profile"
    end
  end
end
