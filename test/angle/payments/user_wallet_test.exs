defmodule Angle.Payments.UserWalletTest do
  use Angle.DataCase

  require Ash.Query

  alias Angle.Payments.UserWallet
  alias Angle.Payments.WalletTransaction

  describe "create wallet" do
    test "creates wallet with default zero balance" do
      user = create_user()

      assert {:ok, wallet} =
               UserWallet
               |> Ash.Changeset.for_create(:create, %{}, actor: user, authorize?: false)
               |> Ash.create()

      assert wallet.user_id == user.id
      assert Decimal.equal?(wallet.balance, Decimal.new("0"))
      assert Decimal.equal?(wallet.total_deposited, Decimal.new("0"))
      assert Decimal.equal?(wallet.total_withdrawn, Decimal.new("0"))
    end

    test "prevents duplicate wallets for same user" do
      user = create_user()

      {:ok, _wallet1} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user, authorize?: false)
        |> Ash.create()

      result =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user, authorize?: false)
        |> Ash.create()

      # The second create should fail
      assert {:error, _error} = result
    end
  end

  describe "read wallet" do
    test "reads wallet by user_id" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user, authorize?: false)
        |> Ash.create()

      found_wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert found_wallet.id == wallet.id
    end
  end

  describe "deposit" do
    test "increases balance and total_deposited" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user, authorize?: false)
        |> Ash.create()

      {:ok, updated_wallet} =
        wallet
        |> Ash.Changeset.for_update(:deposit, %{amount: Decimal.new("100.00")}, authorize?: false)
        |> Ash.update()

      assert Decimal.equal?(updated_wallet.balance, Decimal.new("100.00"))
      assert Decimal.equal?(updated_wallet.total_deposited, Decimal.new("100.00"))
      assert Decimal.equal?(updated_wallet.total_withdrawn, Decimal.new("0"))

      # Verify transaction created
      transactions =
        WalletTransaction
        |> Ash.Query.filter(wallet_id == ^wallet.id and transaction_type == :deposit)
        |> Ash.read!(authorize?: false)

      assert length(transactions) == 1
      txn = hd(transactions)
      assert Decimal.equal?(txn.amount, Decimal.new("100.00"))
      assert Decimal.equal?(txn.balance_before, Decimal.new("0"))
      assert Decimal.equal?(txn.balance_after, Decimal.new("100.00"))
    end

    test "handles multiple deposits" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user, authorize?: false)
        |> Ash.create()

      {:ok, wallet} =
        wallet
        |> Ash.Changeset.for_update(:deposit, %{amount: Decimal.new("50.00")}, authorize?: false)
        |> Ash.update()

      {:ok, wallet} =
        wallet
        |> Ash.Changeset.for_update(:deposit, %{amount: Decimal.new("75.00")}, authorize?: false)
        |> Ash.update()

      assert Decimal.equal?(wallet.balance, Decimal.new("125.00"))
      assert Decimal.equal?(wallet.total_deposited, Decimal.new("125.00"))
    end

    test "rejects negative deposit amounts" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user, authorize?: false)
        |> Ash.create()

      result =
        wallet
        |> Ash.Changeset.for_update(:deposit, %{amount: Decimal.new("-10.00")}, authorize?: false)
        |> Ash.update()

      assert {:error, _error} = result
    end
  end

  describe "withdraw" do
    test "decreases balance and increases total_withdrawn" do
      user = create_user()
      wallet = create_wallet(user: user, balance: Decimal.new("100.00"))

      # Then withdraw
      {:ok, updated_wallet} =
        wallet
        |> Ash.Changeset.for_update(
          :withdraw,
          %{
            amount: Decimal.new("30.00"),
            bank_details: %{
              bank_name: "Test Bank",
              account_number: "1234567890",
              account_name: "Test User"
            }
          },
          authorize?: false
        )
        |> Ash.update()

      assert Decimal.equal?(updated_wallet.balance, Decimal.new("70.00"))
      assert Decimal.equal?(updated_wallet.total_withdrawn, Decimal.new("30.00"))
      assert Decimal.equal?(updated_wallet.total_deposited, Decimal.new("100.00"))

      # Verify transaction created
      transactions =
        WalletTransaction
        |> Ash.Query.filter(wallet_id == ^wallet.id and transaction_type == :withdrawal)
        |> Ash.read!(authorize?: false)

      assert length(transactions) == 1
      txn = hd(transactions)
      assert Decimal.equal?(txn.amount, Decimal.new("30.00"))
      assert Decimal.equal?(txn.balance_before, Decimal.new("100.00"))
      assert Decimal.equal?(txn.balance_after, Decimal.new("70.00"))
    end

    test "rejects withdrawal when insufficient balance" do
      user = create_user()
      wallet = create_wallet(user: user, balance: Decimal.new("50.00"))

      # Try to withdraw 100 (more than balance)
      result =
        wallet
        |> Ash.Changeset.for_update(
          :withdraw,
          %{
            amount: Decimal.new("100.00"),
            bank_details: %{
              bank_name: "Test Bank",
              account_number: "1234567890",
              account_name: "Test User"
            }
          },
          authorize?: false
        )
        |> Ash.update()

      assert {:error, _error} = result
    end

    test "rejects negative withdrawal amounts" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user, authorize?: false)
        |> Ash.create()

      result =
        wallet
        |> Ash.Changeset.for_update(
          :withdraw,
          %{
            amount: Decimal.new("-10.00"),
            bank_details: %{
              bank_name: "Test Bank",
              account_number: "1234567890",
              account_name: "Test User"
            }
          },
          authorize?: false
        )
        |> Ash.update()

      assert {:error, _error} = result
    end
  end

  describe "check_minimum_balance" do
    test "passes when balance is sufficient" do
      user = create_user()
      wallet = create_wallet(user: user, balance: Decimal.new("100.00"))

      # Check for 50 (should pass)
      {:ok, [_wallet]} =
        UserWallet
        |> Ash.Query.filter(id == ^wallet.id)
        |> Ash.Query.for_read(:check_minimum_balance, %{
          required_amount: Decimal.new("50.00")
        })
        |> Ash.read(authorize?: false)
    end

    test "fails when balance is insufficient" do
      user = create_user()
      wallet = create_wallet(user: user, balance: Decimal.new("30.00"))

      # Check for 50 (should fail)
      result =
        UserWallet
        |> Ash.Query.filter(id == ^wallet.id)
        |> Ash.Query.for_read(:check_minimum_balance, %{
          required_amount: Decimal.new("50.00")
        })
        |> Ash.read(authorize?: false)

      assert {:error, _error} = result
    end
  end
end
