defmodule Angle.Payments.PaymentMethodTest do
  use Angle.DataCase, async: true

  alias Angle.Payments.PaymentMethod

  describe "create" do
    test "creates a payment method with valid attributes" do
      user = create_user()

      method =
        PaymentMethod
        |> Ash.Changeset.for_create(
          :create,
          %{
            card_type: "visa",
            last_four: "1234",
            exp_month: "12",
            exp_year: "2030",
            authorization_code: "AUTH_test123",
            bank: "GTBank",
            paystack_reference: "angle_test_ref123",
            user_id: user.id
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      assert method.card_type == "visa"
      assert method.last_four == "1234"
      assert method.exp_month == "12"
      assert method.exp_year == "2030"
      assert method.bank == "GTBank"
      assert method.user_id == user.id
    end

    test "prevents creating a payment method for another user" do
      user1 = create_user()
      user2 = create_user()

      assert {:error, %Ash.Error.Forbidden{}} =
               PaymentMethod
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   card_type: "visa",
                   last_four: "1234",
                   exp_month: "12",
                   exp_year: "2030",
                   authorization_code: "AUTH_test456",
                   bank: "GTBank",
                   paystack_reference: "angle_test_ref456",
                   user_id: user2.id
                 },
                 actor: user1
               )
               |> Ash.create(actor: user1)
    end

    test "prevents duplicate paystack_reference (replay prevention)" do
      user = create_user()
      create_payment_method(%{user: user, paystack_reference: "angle_replay_test"})

      assert {:error, %Ash.Error.Invalid{}} =
               PaymentMethod
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   card_type: "mastercard",
                   last_four: "5678",
                   exp_month: "06",
                   exp_year: "2027",
                   authorization_code: "AUTH_replay",
                   bank: "Access Bank",
                   paystack_reference: "angle_replay_test",
                   user_id: user.id
                 },
                 authorize?: false
               )
               |> Ash.create(authorize?: false)
    end
  end

  describe "list_by_user" do
    test "returns only the current user's payment methods" do
      user1 = create_user()
      user2 = create_user()
      create_payment_method(%{user: user1})
      create_payment_method(%{user: user2})

      methods = Ash.read!(PaymentMethod, action: :list_by_user, actor: user1)
      assert length(methods) == 1
      assert Enum.all?(methods, fn m -> m.user_id == user1.id end)
    end

    test "does not expose authorization_code via field policy" do
      user = create_user()
      create_payment_method(%{user: user})

      [method] = Ash.read!(PaymentMethod, action: :list_by_user, actor: user)
      assert %Ash.ForbiddenField{} = method.authorization_code
    end

    test "does not expose paystack_reference via field policy" do
      user = create_user()
      create_payment_method(%{user: user})

      [method] = Ash.read!(PaymentMethod, action: :list_by_user, actor: user)
      assert %Ash.ForbiddenField{} = method.paystack_reference
    end
  end

  describe "destroy" do
    test "owner can destroy their payment method" do
      user = create_user()
      create_payment_method(%{user: user})

      # Fetch through authorized read action, then destroy
      [method] = Ash.read!(PaymentMethod, action: :list_by_user, actor: user)
      assert :ok = Ash.destroy!(method, action: :destroy, actor: user)

      # Verify it's actually gone
      assert [] = Ash.read!(PaymentMethod, action: :list_by_user, actor: user)
    end

    test "non-owner cannot destroy another user's payment method" do
      user1 = create_user()
      user2 = create_user()
      create_payment_method(%{user: user1})

      # Fetch through authorized read action as the owner
      [method] = Ash.read!(PaymentMethod, action: :list_by_user, actor: user1)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.destroy(method, action: :destroy, actor: user2)
    end
  end
end
