defmodule Angle.Payments.WalletTransactionTest do
  use Angle.DataCase

  require Ash.Query

  alias Angle.Payments.{UserWallet, WalletTransaction}

  describe "create transaction" do
    test "creates deposit transaction with all required fields" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert {:ok, transaction} =
               WalletTransaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   wallet_id: wallet.id,
                   amount: Decimal.new("1000.00"),
                   transaction_type: :deposit,
                   balance_before: Decimal.new("0"),
                   balance_after: Decimal.new("1000.00"),
                   reference: "test_ref_123"
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert transaction.wallet_id == wallet.id
      assert Decimal.equal?(transaction.amount, Decimal.new("1000.00"))
      assert transaction.transaction_type == :deposit
      assert Decimal.equal?(transaction.balance_before, Decimal.new("0"))
      assert Decimal.equal?(transaction.balance_after, Decimal.new("1000.00"))
      assert transaction.reference == "test_ref_123"
    end

    test "creates withdrawal transaction" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert {:ok, transaction} =
               WalletTransaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   wallet_id: wallet.id,
                   amount: Decimal.new("500.00"),
                   transaction_type: :withdrawal,
                   balance_before: Decimal.new("1000.00"),
                   balance_after: Decimal.new("500.00"),
                   reference: "withdrawal_ref"
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert transaction.transaction_type == :withdrawal
      assert Decimal.equal?(transaction.amount, Decimal.new("500.00"))
      assert Decimal.equal?(transaction.balance_before, Decimal.new("1000.00"))
      assert Decimal.equal?(transaction.balance_after, Decimal.new("500.00"))
    end

    test "creates refund transaction with metadata" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      metadata = %{original_bid_id: "bid_123", reason: "auction cancelled"}

      assert {:ok, transaction} =
               WalletTransaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   wallet_id: wallet.id,
                   amount: Decimal.new("2000.00"),
                   transaction_type: :refund,
                   balance_before: Decimal.new("0"),
                   balance_after: Decimal.new("2000.00"),
                   reference: "refund_ref",
                   metadata: metadata
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert transaction.transaction_type == :refund
      assert Decimal.equal?(transaction.balance_before, Decimal.new("0"))
      assert Decimal.equal?(transaction.balance_after, Decimal.new("2000.00"))
      assert transaction.metadata["original_bid_id"] == "bid_123"
      assert transaction.metadata["reason"] == "auction cancelled"
    end

    test "creates purchase transaction" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert {:ok, transaction} =
               WalletTransaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   wallet_id: wallet.id,
                   amount: Decimal.new("3000.00"),
                   transaction_type: :purchase,
                   balance_before: Decimal.new("5000.00"),
                   balance_after: Decimal.new("2000.00"),
                   reference: "purchase_ref"
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert transaction.transaction_type == :purchase
      assert Decimal.equal?(transaction.amount, Decimal.new("3000.00"))
    end

    test "creates sale_credit transaction" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert {:ok, transaction} =
               WalletTransaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   wallet_id: wallet.id,
                   amount: Decimal.new("10000.00"),
                   transaction_type: :sale_credit,
                   balance_before: Decimal.new("5000.00"),
                   balance_after: Decimal.new("15000.00"),
                   reference: "sale_ref"
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert transaction.transaction_type == :sale_credit
      assert Decimal.equal?(transaction.amount, Decimal.new("10000.00"))
    end

    test "creates commission transaction" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert {:ok, transaction} =
               WalletTransaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   wallet_id: wallet.id,
                   amount: Decimal.new("100.00"),
                   transaction_type: :commission,
                   balance_before: Decimal.new("1000.00"),
                   balance_after: Decimal.new("900.00"),
                   reference: "commission_ref"
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert transaction.transaction_type == :commission
      assert Decimal.equal?(transaction.amount, Decimal.new("100.00"))
    end
  end

  describe "read transactions" do
    test "reads transactions by wallet_id" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      {:ok, _tx1} =
        WalletTransaction
        |> Ash.Changeset.for_create(
          :create,
          %{
            wallet_id: wallet.id,
            amount: Decimal.new("1000.00"),
            transaction_type: :deposit,
            balance_before: Decimal.new("0"),
            balance_after: Decimal.new("1000.00"),
            reference: "ref1"
          },
          authorize?: false
        )
        |> Ash.create()

      {:ok, _tx2} =
        WalletTransaction
        |> Ash.Changeset.for_create(
          :create,
          %{
            wallet_id: wallet.id,
            amount: Decimal.new("500.00"),
            transaction_type: :withdrawal,
            balance_before: Decimal.new("1000.00"),
            balance_after: Decimal.new("500.00"),
            reference: "ref2"
          },
          authorize?: false
        )
        |> Ash.create()

      transactions =
        WalletTransaction
        |> Ash.Query.filter(wallet_id == ^wallet.id)
        |> Ash.read!(authorize?: false)

      assert length(transactions) == 2
    end
  end

  describe "validations" do
    test "rejects negative amount" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert {:error, error} =
               WalletTransaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   wallet_id: wallet.id,
                   amount: Decimal.new("-100.00"),
                   transaction_type: :deposit,
                   balance_before: Decimal.new("0"),
                   balance_after: Decimal.new("-100.00"),
                   reference: "negative_ref"
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message || "", "amount must be positive")
             end)
    end

    test "rejects zero amount" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert {:error, error} =
               WalletTransaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   wallet_id: wallet.id,
                   amount: Decimal.new("0"),
                   transaction_type: :deposit,
                   balance_before: Decimal.new("0"),
                   balance_after: Decimal.new("0"),
                   reference: "zero_ref"
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message || "", "amount must be positive")
             end)
    end

    test "rejects incorrect balance arithmetic for deposit" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert {:error, error} =
               WalletTransaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   wallet_id: wallet.id,
                   amount: Decimal.new("1000.00"),
                   transaction_type: :deposit,
                   balance_before: Decimal.new("500.00"),
                   balance_after: Decimal.new("1000.00"),
                   reference: "wrong_math_ref"
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message || "", "balance_after must equal balance_before") and
                 String.contains?(err.message || "", "expected 1500")
             end)
    end

    test "rejects incorrect balance arithmetic for withdrawal" do
      user = create_user()

      # Wallet is automatically created by registration hook
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert {:error, error} =
               WalletTransaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   wallet_id: wallet.id,
                   amount: Decimal.new("300.00"),
                   transaction_type: :withdrawal,
                   balance_before: Decimal.new("1000.00"),
                   balance_after: Decimal.new("800.00"),
                   reference: "wrong_withdrawal_ref"
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message || "", "balance_after must equal balance_before") and
                 String.contains?(err.message || "", "expected 700")
             end)
    end
  end
end
