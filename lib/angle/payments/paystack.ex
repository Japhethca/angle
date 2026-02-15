defmodule Angle.Payments.Paystack do
  @moduledoc "Paystack API client using Req for direct HTTP calls."
  @behaviour Angle.Payments.PaystackBehaviour

  @base_url "https://api.paystack.co"

  @doc "Initialize a transaction for card tokenization. Amount in kobo."
  def initialize_transaction(email, amount_kobo, opts \\ []) do
    reference = opts[:reference] || generate_reference()

    body = %{
      email: email,
      amount: amount_kobo,
      reference: reference,
      channels: ["card"]
    }

    case post("/transaction/initialize", body) do
      {:ok, %{"status" => true, "data" => data}} ->
        {:ok,
         %{
           authorization_url: data["authorization_url"],
           access_code: data["access_code"],
           reference: data["reference"]
         }}

      {:ok, %{"status" => false, "message" => message}} ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Verify a transaction and return authorization details."
  def verify_transaction(reference) do
    case get("/transaction/verify/#{URI.encode(reference)}") do
      {:ok, %{"status" => true, "data" => data}} ->
        {:ok,
         %{
           status: data["status"],
           amount: data["amount"],
           reference: data["reference"],
           authorization: parse_authorization(data["authorization"])
         }}

      {:ok, %{"status" => false, "message" => message}} ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "List Nigerian banks."
  def list_banks do
    case get("/bank") do
      {:ok, %{"status" => true, "data" => banks}} ->
        {:ok,
         Enum.map(banks, fn bank ->
           %{name: bank["name"], code: bank["code"]}
         end)}

      {:ok, %{"status" => false, "message" => message}} ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Resolve a bank account number to get the account name."
  def resolve_account(account_number, bank_code) do
    case get("/bank/resolve", account_number: account_number, bank_code: bank_code) do
      {:ok, %{"status" => true, "data" => data}} ->
        {:ok,
         %{
           account_number: data["account_number"],
           account_name: data["account_name"]
         }}

      {:ok, %{"status" => false, "message" => message}} ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Create a transfer recipient for bank payouts."
  def create_transfer_recipient(name, account_number, bank_code) do
    body = %{
      type: "nuban",
      name: name,
      account_number: account_number,
      bank_code: bank_code,
      currency: "NGN"
    }

    case post("/transferrecipient", body) do
      {:ok, %{"status" => true, "data" => data}} ->
        {:ok, %{recipient_code: data["recipient_code"]}}

      {:ok, %{"status" => false, "message" => message}} ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helpers

  defp post(path, body) do
    url = @base_url <> path

    case Req.post(url, json: body, headers: headers()) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{body: body}} ->
        {:error, body["message"] || "Paystack API error"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  defp get(path, params \\ []) do
    url = @base_url <> path

    case Req.get(url, params: params, headers: headers()) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{body: body}} ->
        {:error, body["message"] || "Paystack API error"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  defp headers do
    [{"authorization", "Bearer #{secret_key()}"}]
  end

  defp secret_key do
    Application.get_env(:angle, :paystack_secret_key) ||
      raise "Paystack secret key not configured. Set :paystack_secret_key in config."
  end

  defp generate_reference do
    "angle_" <> Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
  end

  defp parse_authorization(nil), do: nil

  defp parse_authorization(auth) do
    %{
      authorization_code: auth["authorization_code"],
      card_type: auth["card_type"],
      last4: auth["last4"],
      exp_month: auth["exp_month"],
      exp_year: auth["exp_year"],
      bank: auth["bank"],
      reusable: auth["reusable"]
    }
  end
end
