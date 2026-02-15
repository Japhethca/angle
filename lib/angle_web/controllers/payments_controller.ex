defmodule AngleWeb.PaymentsController do
  use AngleWeb, :controller

  alias Angle.Payments.PaymentMethod
  alias Angle.Payments.PayoutMethod

  @paystack Application.compile_env(:angle, :paystack_client, Angle.Payments.Paystack)

  # ₦50 in kobo — small charge to verify card ownership
  @card_verification_amount 5000

  # POST /api/payments/initialize-card
  # Initializes a Paystack transaction for card tokenization
  def initialize_card(conn, _params) do
    user = conn.assigns.current_user

    case @paystack.initialize_transaction(to_string(user.email), @card_verification_amount) do
      {:ok, data} ->
        json(conn, %{access_code: data.access_code, reference: data.reference})

      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: reason})
    end
  end

  # POST /api/payments/verify-card
  # Verifies a Paystack transaction and saves the card
  def verify_card(conn, %{"reference" => reference})
      when is_binary(reference) and byte_size(reference) > 0 do
    user = conn.assigns.current_user

    with {:ok, transaction} <- @paystack.verify_transaction(reference),
         :ok <- validate_transaction(transaction),
         {:ok, _payment_method} <- create_payment_method(user, transaction) do
      json(conn, %{success: true})
    else
      {:error, reason} when is_binary(reason) ->
        conn |> put_status(422) |> json(%{error: reason})

      {:error, %Ash.Error.Invalid{} = error} ->
        conn |> put_status(422) |> json(%{error: error_message(error)})

      {:error, _} ->
        conn |> put_status(422) |> json(%{error: "Failed to save payment method"})
    end
  end

  def verify_card(conn, _params) do
    conn |> put_status(422) |> json(%{error: "Missing or invalid reference"})
  end

  # DELETE /api/payments/payment-methods/:id
  def delete_payment_method(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, method} <- Ash.get(PaymentMethod, id, actor: user),
         :ok <- Ash.destroy(method, actor: user) do
      json(conn, %{success: true})
    else
      {:error, _} ->
        conn |> put_status(404) |> json(%{error: "Payment method not found"})
    end
  end

  # POST /api/payments/add-payout
  # Resolves bank account, creates transfer recipient, saves payout method
  def add_payout(conn, %{
        "bank_code" => bank_code,
        "bank_name" => bank_name,
        "account_number" => account_number
      })
      when is_binary(bank_code) and is_binary(bank_name) and is_binary(account_number) do
    if Regex.match?(~r/^\d{10}$/, account_number) do
      user = conn.assigns.current_user

      with {:ok, resolved} <- @paystack.resolve_account(account_number, bank_code),
           {:ok, recipient} <-
             @paystack.create_transfer_recipient(resolved.account_name, account_number, bank_code),
           {:ok, _payout} <-
             create_payout_method(
               user,
               bank_name,
               bank_code,
               account_number,
               resolved.account_name,
               recipient.recipient_code
             ) do
        json(conn, %{success: true})
      else
        {:error, reason} when is_binary(reason) ->
          conn |> put_status(422) |> json(%{error: reason})

        {:error, _} ->
          conn |> put_status(422) |> json(%{error: "Failed to add payout method"})
      end
    else
      conn |> put_status(422) |> json(%{error: "Account number must be 10 digits"})
    end
  end

  def add_payout(conn, _params) do
    conn |> put_status(422) |> json(%{error: "Missing bank_code or account_number"})
  end

  # DELETE /api/payments/payout-methods/:id
  def delete_payout_method(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, method} <- Ash.get(PayoutMethod, id, actor: user),
         :ok <- Ash.destroy(method, actor: user) do
      json(conn, %{success: true})
    else
      {:error, _} ->
        conn |> put_status(404) |> json(%{error: "Payout method not found"})
    end
  end

  # GET /api/payments/banks
  # Lists banks from Paystack (could add caching later)
  def list_banks(conn, _params) do
    case @paystack.list_banks() do
      {:ok, banks} -> json(conn, %{banks: banks})
      {:error, _} -> conn |> put_status(500) |> json(%{error: "Failed to fetch banks"})
    end
  end

  # --- Private helpers ---

  defp validate_transaction(%{status: "success", amount: amount})
       when amount == @card_verification_amount,
       do: :ok

  defp validate_transaction(%{status: "success", amount: _}),
    do: {:error, "Invalid transaction amount"}

  defp validate_transaction(_), do: {:error, "Transaction was not successful"}

  defp create_payment_method(user, %{reference: reference, authorization: auth}) do
    PaymentMethod
    |> Ash.Changeset.for_create(
      :create,
      %{
        card_type: auth.card_type,
        last_four: auth.last4,
        exp_month: auth.exp_month,
        exp_year: auth.exp_year,
        authorization_code: auth.authorization_code,
        bank: auth.bank,
        paystack_reference: reference,
        user_id: user.id
      },
      actor: user
    )
    |> Ash.create()
  end

  defp create_payout_method(
         user,
         bank_name,
         bank_code,
         account_number,
         account_name,
         recipient_code
       ) do
    PayoutMethod
    |> Ash.Changeset.for_create(
      :create,
      %{
        bank_name: bank_name,
        bank_code: bank_code,
        account_number: account_number,
        account_name: account_name,
        recipient_code: recipient_code,
        user_id: user.id
      },
      actor: user
    )
    |> Ash.create()
  end

  defp error_message(%Ash.Error.Invalid{errors: errors}) do
    Enum.map_join(errors, ", ", & &1.message)
  end

  defp error_message(_), do: "An error occurred"
end
