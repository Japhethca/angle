defmodule Angle.Payments.UserWalletTest do
  use Angle.DataCase

  require Ash.Query

  alias Angle.Payments.UserWallet

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
end
