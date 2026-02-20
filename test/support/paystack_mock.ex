defmodule Angle.Payments.PaystackMock do
  @moduledoc "Test mock for Paystack API client."
  @behaviour Angle.Payments.PaystackBehaviour

  @impl true
  def initialize_transaction(_email, _amount, _opts \\ []) do
    {:ok,
     %{
       authorization_url: "https://checkout.paystack.com/test",
       access_code: "test_access_code",
       reference: "angle_test_ref_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
     }}
  end

  @impl true
  def verify_transaction(reference) do
    {:ok,
     %{
       status: "success",
       amount: 5000,
       reference: reference,
       authorization: %{
         authorization_code: "AUTH_mock_test",
         card_type: "visa",
         last4: "4081",
         exp_month: "12",
         exp_year: "2030",
         bank: "TEST BANK",
         reusable: true
       }
     }}
  end

  @impl true
  def list_banks do
    {:ok,
     [
       %{name: "Access Bank", code: "044"},
       %{name: "GTBank", code: "058"},
       %{name: "Kuda Bank", code: "090267"}
     ]}
  end

  @impl true
  def resolve_account(_account_number, _bank_code) do
    {:ok,
     %{
       account_number: "1234567890",
       account_name: "JOHN DOE"
     }}
  end

  @impl true
  def create_transfer_recipient(_name, _account_number, _bank_code) do
    {:ok, %{recipient_code: "RCP_mock_test"}}
  end

  @impl true
  def create_subaccount(_params) do
    {:ok,
     %{
       "subaccount_code" => "ACCT_mock_test",
       "business_name" => "Test Business",
       "settlement_bank" => "044",
       "account_number" => "1234567890",
       "percentage_charge" => 0
     }}
  end
end
