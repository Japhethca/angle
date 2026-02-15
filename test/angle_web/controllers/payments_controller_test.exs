defmodule AngleWeb.PaymentsControllerTest do
  use AngleWeb.ConnCase

  defp authed_conn(conn, user) do
    conn |> init_test_session(%{current_user_id: user.id})
  end

  describe "POST /api/payments/initialize-card" do
    test "returns access_code and reference for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/api/payments/initialize-card")

      assert %{"access_code" => _, "reference" => _} = json_response(conn, 200)
    end

    test "redirects when not authenticated", %{conn: conn} do
      conn = post(conn, ~p"/api/payments/initialize-card")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "POST /api/payments/verify-card" do
    test "verifies transaction and creates payment method", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> authed_conn(user)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/payments/verify-card", %{reference: "test_ref_123"})

      assert %{"success" => true} = json_response(conn, 200)

      # Verify payment method was created
      [method] =
        Ash.read!(Angle.Payments.PaymentMethod,
          action: :list_by_user,
          actor: user
        )

      assert method.card_type == "visa"
      assert method.last_four == "4081"
      assert method.exp_month == "12"
      assert method.exp_year == "2030"
    end

    test "returns 422 for missing reference", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> authed_conn(user)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/payments/verify-card", %{})

      assert %{"error" => "Missing or invalid reference"} = json_response(conn, 422)
    end

    test "returns 422 for empty reference", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> authed_conn(user)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/payments/verify-card", %{reference: ""})

      assert %{"error" => "Missing or invalid reference"} = json_response(conn, 422)
    end

    test "redirects when not authenticated", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/payments/verify-card", %{reference: "test"})

      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "DELETE /api/payments/payment-methods/:id" do
    test "deletes own payment method", %{conn: conn} do
      user = create_user()
      method = create_payment_method(%{user: user})

      conn =
        conn
        |> authed_conn(user)
        |> delete(~p"/api/payments/payment-methods/#{method.id}")

      assert %{"success" => true} = json_response(conn, 200)

      # Verify it's deleted
      assert [] ==
               Ash.read!(Angle.Payments.PaymentMethod,
                 action: :list_by_user,
                 actor: user
               )
    end

    test "returns 404 for another user's payment method", %{conn: conn} do
      user1 = create_user()
      user2 = create_user()
      method = create_payment_method(%{user: user1})

      conn =
        conn
        |> authed_conn(user2)
        |> delete(~p"/api/payments/payment-methods/#{method.id}")

      assert %{"error" => "Payment method not found"} = json_response(conn, 404)
    end

    test "returns 404 for non-existent id", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> authed_conn(user)
        |> delete(~p"/api/payments/payment-methods/#{Ash.UUID.generate()}")

      assert %{"error" => "Payment method not found"} = json_response(conn, 404)
    end

    test "redirects when not authenticated", %{conn: conn} do
      conn = delete(conn, ~p"/api/payments/payment-methods/#{Ash.UUID.generate()}")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "POST /api/payments/add-payout" do
    test "creates payout method with valid data", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> authed_conn(user)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/payments/add-payout", %{
          bank_code: "058",
          bank_name: "GTBank",
          account_number: "1234567890"
        })

      assert %{"success" => true} = json_response(conn, 200)

      # Verify payout method was created
      [payout] =
        Ash.read!(Angle.Payments.PayoutMethod,
          action: :list_by_user,
          actor: user
        )

      assert payout.bank_name == "GTBank"
      assert payout.account_name == "JOHN DOE"
    end

    test "returns 422 for invalid account number (not 10 digits)", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> authed_conn(user)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/payments/add-payout", %{
          bank_code: "058",
          bank_name: "GTBank",
          account_number: "12345"
        })

      assert %{"error" => "Account number must be 10 digits"} = json_response(conn, 422)
    end

    test "returns 422 for missing params", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> authed_conn(user)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/payments/add-payout", %{})

      assert %{"error" => _} = json_response(conn, 422)
    end

    test "redirects when not authenticated", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/payments/add-payout", %{
          bank_code: "058",
          bank_name: "GTBank",
          account_number: "1234567890"
        })

      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "DELETE /api/payments/payout-methods/:id" do
    test "deletes own payout method", %{conn: conn} do
      user = create_user()
      method = create_payout_method(%{user: user})

      conn =
        conn
        |> authed_conn(user)
        |> delete(~p"/api/payments/payout-methods/#{method.id}")

      assert %{"success" => true} = json_response(conn, 200)
    end

    test "returns 404 for another user's payout method", %{conn: conn} do
      user1 = create_user()
      user2 = create_user()
      method = create_payout_method(%{user: user1})

      conn =
        conn
        |> authed_conn(user2)
        |> delete(~p"/api/payments/payout-methods/#{method.id}")

      assert %{"error" => "Payout method not found"} = json_response(conn, 404)
    end

    test "redirects when not authenticated", %{conn: conn} do
      conn = delete(conn, ~p"/api/payments/payout-methods/#{Ash.UUID.generate()}")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "GET /api/payments/banks" do
    test "returns list of banks", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/payments/banks")

      assert %{"banks" => banks} = json_response(conn, 200)
      assert is_list(banks)
      assert length(banks) > 0
      assert Enum.all?(banks, fn b -> Map.has_key?(b, "name") and Map.has_key?(b, "code") end)
    end

    test "redirects when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/api/payments/banks")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end
end
