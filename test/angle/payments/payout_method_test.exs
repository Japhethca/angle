defmodule Angle.Payments.PayoutMethodTest do
  use Angle.DataCase, async: true

  alias Angle.Payments.PayoutMethod

  describe "create" do
    test "creates a payout method with valid attributes" do
      user = create_user()

      method =
        PayoutMethod
        |> Ash.Changeset.for_create(
          :create,
          %{
            bank_name: "Kuda Bank",
            bank_code: "090267",
            account_number: "2009568002",
            account_name: "Test User",
            recipient_code: "RCP_test123",
            user_id: user.id
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      assert method.bank_name == "Kuda Bank"
      assert method.account_number == "2009568002"
      assert method.account_name == "Test User"
      assert method.user_id == user.id
    end

    test "prevents creating a payout method for another user" do
      user1 = create_user()
      user2 = create_user()

      assert {:error, %Ash.Error.Forbidden{}} =
               PayoutMethod
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   bank_name: "Kuda Bank",
                   bank_code: "090267",
                   account_number: "2009568002",
                   account_name: "Test User",
                   recipient_code: "RCP_test456",
                   user_id: user2.id
                 },
                 actor: user1
               )
               |> Ash.create(actor: user1)
    end
  end

  describe "list_by_user" do
    test "returns only the current user's payout methods" do
      user1 = create_user()
      user2 = create_user()
      create_payout_method(%{user: user1})
      create_payout_method(%{user: user2})

      methods = Ash.read!(PayoutMethod, action: :list_by_user, actor: user1)
      assert length(methods) == 1
      assert Enum.all?(methods, fn m -> m.user_id == user1.id end)
    end

    test "does not expose recipient_code via field policy" do
      user = create_user()
      create_payout_method(%{user: user})

      [method] = Ash.read!(PayoutMethod, action: :list_by_user, actor: user)
      assert %Ash.ForbiddenField{} = method.recipient_code
    end

    test "does not expose bank_code via field policy" do
      user = create_user()
      create_payout_method(%{user: user})

      [method] = Ash.read!(PayoutMethod, action: :list_by_user, actor: user)
      assert %Ash.ForbiddenField{} = method.bank_code
    end
  end

  describe "destroy" do
    test "owner can destroy their payout method" do
      user = create_user()
      create_payout_method(%{user: user})

      # Fetch through authorized read action, then destroy
      [method] = Ash.read!(PayoutMethod, action: :list_by_user, actor: user)
      assert :ok = Ash.destroy!(method, action: :destroy, actor: user)

      # Verify it's actually gone
      assert [] = Ash.read!(PayoutMethod, action: :list_by_user, actor: user)
    end

    test "non-owner cannot destroy another user's payout method" do
      user1 = create_user()
      user2 = create_user()
      create_payout_method(%{user: user1})

      # Fetch through authorized read action as the owner
      [method] = Ash.read!(PayoutMethod, action: :list_by_user, actor: user1)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.destroy(method, action: :destroy, actor: user2)
    end
  end
end
