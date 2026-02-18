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

  describe "DELETE /store/listings/:id" do
    setup do
      # Create seller role with delete_own_items permission
      role = create_role(%{name: "seller_#{System.unique_integer([:positive])}"})

      permission =
        Ash.create!(
          Angle.Accounts.Permission,
          %{name: "delete_own_items", resource: "item", action: "delete", scope: "own"},
          authorize?: false,
          upsert?: true,
          upsert_identity: :name_resource_action
        )

      Ash.create!(
        Angle.Accounts.RolePermission,
        %{role_id: role.id, permission_id: permission.id},
        authorize?: false
      )

      %{seller_role: role}
    end

    defp create_seller(seller_role) do
      user = create_user()

      Angle.Accounts.User.assign_role(user, %{role_name: seller_role.name}, authorize?: false)

      user
    end

    test "deletes own item and redirects with success flash", %{
      conn: conn,
      seller_role: seller_role
    } do
      user = create_seller(seller_role)
      item = create_item(%{created_by_id: user.id})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> delete(~p"/store/listings/#{item.id}")

      assert redirected_to(conn) == ~p"/store/listings"
      assert Phoenix.Flash.get(conn.assigns.flash, :success) == "Item deleted successfully"

      # Verify item is actually deleted
      assert {:error, _} = Angle.Inventory.get_item(item.id, authorize?: false)
    end

    test "returns error flash for non-existent item", %{
      conn: conn,
      seller_role: seller_role
    } do
      user = create_seller(seller_role)

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> delete(~p"/store/listings/#{Ecto.UUID.generate()}")

      assert redirected_to(conn) == ~p"/store/listings"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Item not found"
    end

    test "returns error flash for invalid UUID", %{conn: conn, seller_role: seller_role} do
      user = create_seller(seller_role)

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> delete(~p"/store/listings/not-a-uuid")

      assert redirected_to(conn) == ~p"/store/listings"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "delete item"
    end

    test "returns error flash when deleting another user's item", %{
      conn: conn,
      seller_role: seller_role
    } do
      user = create_seller(seller_role)
      other_user = create_user()
      item = create_item(%{created_by_id: other_user.id})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> delete(~p"/store/listings/#{item.id}")

      assert redirected_to(conn) == ~p"/store/listings"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) != nil
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = delete(conn, ~p"/store/listings/#{Ecto.UUID.generate()}")
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
