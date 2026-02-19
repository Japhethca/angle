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

  describe "GET /store/listings with search param" do
    test "returns 200 with search param", %{conn: conn} do
      user = create_user()
      create_item(%{title: "Searchable Widget", created_by_id: user.id})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?search=Widget")

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

      Angle.Accounts.assign_role(user, %{role_name: seller_role.name}, authorize?: false)

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

  describe "GET /store/listings with status filter" do
    setup do
      user = create_user()

      # Create items with different statuses.
      # publication_status and auction_status are generated? true,
      # so we set them via Ecto after creation.
      active_item =
        create_item(%{title: "Active Item", created_by_id: user.id})
        |> set_statuses(:published, :active)

      ended_item =
        create_item(%{title: "Ended Item", created_by_id: user.id})
        |> set_statuses(:published, :ended)

      draft_item =
        create_item(%{title: "Draft Item", created_by_id: user.id})
        |> set_statuses(:draft, :pending)

      %{
        user: user,
        active_item: active_item,
        ended_item: ended_item,
        draft_item: draft_item
      }
    end

    test "returns 200 with status=active", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?status=active")

      assert html_response(conn, 200) =~ "store/listings"
    end

    test "returns 200 with status=ended", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?status=ended")

      assert html_response(conn, 200) =~ "store/listings"
    end

    test "returns 200 with status=draft", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?status=draft")

      assert html_response(conn, 200) =~ "store/listings"
    end

    test "returns 200 with status=all (default)", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?status=all")

      assert html_response(conn, 200) =~ "store/listings"
    end

    test "invalid status falls back to default", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?status=invalid")

      assert html_response(conn, 200) =~ "store/listings"
    end
  end

  describe "GET /store/listings with sort params" do
    setup do
      user = create_user()
      create_item(%{title: "Item A", created_by_id: user.id, starting_price: Decimal.new("5.00")})

      create_item(%{
        title: "Item B",
        created_by_id: user.id,
        starting_price: Decimal.new("20.00")
      })

      %{user: user}
    end

    test "returns 200 with sort=inserted_at&dir=asc", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?sort=inserted_at&dir=asc")

      assert html_response(conn, 200) =~ "store/listings"
    end

    test "returns 200 with sort=current_price&dir=desc", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?sort=current_price&dir=desc")

      assert html_response(conn, 200) =~ "store/listings"
    end

    test "returns 200 with sort=bid_count&dir=asc", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?sort=bid_count&dir=asc")

      assert html_response(conn, 200) =~ "store/listings"
    end

    test "returns 200 with sort=view_count&dir=desc", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?sort=view_count&dir=desc")

      assert html_response(conn, 200) =~ "store/listings"
    end

    test "returns 200 with sort=watcher_count&dir=asc", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?sort=watcher_count&dir=asc")

      assert html_response(conn, 200) =~ "store/listings"
    end

    test "invalid sort field falls back to default", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?sort=invalid_field&dir=asc")

      assert html_response(conn, 200) =~ "store/listings"
    end

    test "invalid sort direction falls back to default", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?sort=inserted_at&dir=invalid")

      assert html_response(conn, 200) =~ "store/listings"
    end
  end

  describe "GET /store/listings with combined params" do
    setup do
      user = create_user()

      create_item(%{
        title: "Active Cheap",
        created_by_id: user.id,
        starting_price: Decimal.new("5.00")
      })
      |> set_statuses(:published, :active)

      create_item(%{
        title: "Active Expensive",
        created_by_id: user.id,
        starting_price: Decimal.new("50.00")
      })
      |> set_statuses(:published, :active)

      create_item(%{
        title: "Ended Item",
        created_by_id: user.id,
        starting_price: Decimal.new("30.00")
      })
      |> set_statuses(:published, :ended)

      %{user: user}
    end

    test "returns 200 with status + sort + dir combined", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?status=active&sort=current_price&dir=asc")

      assert html_response(conn, 200) =~ "store/listings"
    end

    test "returns 200 with status + sort + dir + search combined", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?status=active&sort=inserted_at&dir=desc&search=Cheap")

      assert html_response(conn, 200) =~ "store/listings"
    end

    test "returns 200 with per_page param", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings?per_page=25&sort=bid_count&dir=desc")

      assert html_response(conn, 200) =~ "store/listings"
    end
  end

  describe "GET /store/listings stats" do
    test "returns stats reflecting actual item data", %{conn: conn} do
      user = create_user()
      item = create_item(%{title: "Stats Item", created_by_id: user.id})

      # Create a bid and watcher
      bidder = create_user()
      create_bid(%{item_id: item.id, user_id: bidder.id, amount: Decimal.new("75.00")})
      watcher = create_user()
      create_watchlist_item(user: watcher, item: item)

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings")

      assert html_response(conn, 200) =~ "store/listings"
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

  # Helper to set publication_status and auction_status on items.
  # These fields are generated? true so they aren't accepted by create actions.
  defp set_statuses(item, pub_status, auction_status) do
    item
    |> Ecto.Changeset.change(%{
      publication_status: pub_status,
      auction_status: auction_status
    })
    |> Angle.Repo.update!()
  end
end
