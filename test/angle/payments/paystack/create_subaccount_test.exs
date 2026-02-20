defmodule Angle.Payments.Paystack.CreateSubaccountTest do
  use Angle.DataCase, async: true

  alias Angle.Payments.Paystack

  describe "create_subaccount/1" do
    setup do
      bypass = Bypass.open()

      # Override Paystack base URL to point to bypass
      original_url = Application.get_env(:angle, :paystack_base_url)
      Application.put_env(:angle, :paystack_base_url, "http://localhost:#{bypass.port}")

      on_exit(fn ->
        if original_url do
          Application.put_env(:angle, :paystack_base_url, original_url)
        else
          Application.delete_env(:angle, :paystack_base_url)
        end
      end)

      {:ok, bypass: bypass}
    end

    test "creates subaccount with user details", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/subaccount", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["business_name"] == "John Doe Store"
        assert params["settlement_bank"] == "999"
        assert params["account_number"] == "0123456789"
        assert params["percentage_charge"] == 0

        response = %{
          "status" => true,
          "message" => "Subaccount created",
          "data" => %{
            "subaccount_code" => "ACCT_abc123xyz",
            "business_name" => "John Doe Store",
            "settlement_bank" => "999",
            "account_number" => "0123456789",
            "percentage_charge" => 0
          }
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end)

      params = %{
        business_name: "John Doe Store",
        settlement_bank: "999",
        account_number: "0123456789"
      }

      assert {:ok, %{"subaccount_code" => "ACCT_abc123xyz"}} =
               Paystack.create_subaccount(params)
    end

    test "handles Paystack API errors", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/subaccount", fn conn ->
        response = %{
          "status" => false,
          "message" => "Invalid bank details"
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(400, Jason.encode!(response))
      end)

      params = %{
        business_name: "Test Store",
        settlement_bank: "invalid",
        account_number: "0000000000"
      }

      assert {:error, "Invalid bank details"} = Paystack.create_subaccount(params)
    end

    test "handles network errors", %{bypass: bypass} do
      Bypass.down(bypass)

      params = %{
        business_name: "Test Store",
        settlement_bank: "999",
        account_number: "0123456789"
      }

      assert {:error, _reason} = Paystack.create_subaccount(params)
    end
  end
end
