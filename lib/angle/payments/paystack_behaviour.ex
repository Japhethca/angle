defmodule Angle.Payments.PaystackBehaviour do
  @moduledoc "Behaviour for Paystack API operations, enabling test mocking."

  @callback initialize_transaction(String.t(), integer(), keyword()) ::
              {:ok, map()} | {:error, String.t()}
  @callback verify_transaction(String.t()) :: {:ok, map()} | {:error, String.t()}
  @callback list_banks() :: {:ok, [map()]} | {:error, String.t()}
  @callback resolve_account(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  @callback create_transfer_recipient(String.t(), String.t(), String.t()) ::
              {:ok, map()} | {:error, String.t()}
end
