defmodule Angle.Bidding.Bid.ValidateWalletCommitmentTest do
  use Angle.DataCase

  alias Angle.Bidding.Bid

  import Angle.Factory

  defp publish_item(item) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
    |> Ash.update!()
  end

  describe "wallet commitment validation for <₦50k items" do
    test "allows bid when user has ₦1,000+ wallet and phone verified" do
      seller = create_user()
      buyer = create_user()

      # Create wallet with sufficient balance
      _wallet = create_wallet(user: buyer, balance: 1500)

      # Create and verify phone
      {:ok, verification} =
        Angle.Accounts.UserVerification
        |> Ash.Changeset.for_create(:create, %{user_id: buyer.id}, authorize?: false)
        |> Ash.create()

      {:ok, verification_with_otp} =
        verification
        |> Ash.Changeset.for_update(
          :request_phone_otp,
          %{phone_number: "+2348012345678"},
          authorize?: false
        )
        |> Ash.update()

      {:ok, _verified} =
        verification_with_otp
        |> Ash.Changeset.for_update(
          :verify_phone_otp,
          %{otp_code: verification_with_otp.otp_code},
          authorize?: false
        )
        |> Ash.update()

      # Create item worth ₦30,000 (<₦50k)
      item =
        create_item(%{
          title: "Low Value Item",
          starting_price: 30_000,
          current_price: 30_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      # Bid should succeed (amount must be at least ₦500 higher than current price)
      assert {:ok, _bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 30_500,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)
    end

    test "rejects bid when wallet balance < ₦1,000" do
      seller = create_user()
      buyer = create_user()

      # Create wallet with insufficient balance
      _wallet = create_wallet(user: buyer, balance: 500)

      # Phone verified
      _verification = create_verification(%{user: buyer, phone_verified: true})

      item =
        create_item(%{
          title: "Low Value Item",
          starting_price: 30_000,
          current_price: 30_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 30_500,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message, "₦1000") and String.contains?(err.message, "wallet")
             end)
    end

    test "rejects bid when phone not verified" do
      seller = create_user()
      buyer = create_user()

      # Sufficient wallet
      _wallet = create_wallet(user: buyer, balance: 2000)

      # Phone NOT verified
      _verification = create_verification(%{user: buyer, phone_verified: false})

      item =
        create_item(%{
          title: "Low Value Item",
          starting_price: 30_000,
          current_price: 30_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 30_500,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message, "phone") and
                 String.contains?(err.message, "verify")
             end)
    end
  end

  describe "wallet commitment validation for ≥₦50k items" do
    test "allows bid when user has ₦5,000+ wallet, phone and ID verified" do
      seller = create_user()
      buyer = create_user()

      # Sufficient wallet
      _wallet = create_wallet(user: buyer, balance: 6000)

      # Phone and ID verified
      _verification =
        create_verification(%{user: buyer, phone_verified: true, id_verified: true})

      # High-value item (₦100k)
      item =
        create_item(%{
          title: "High Value Item",
          starting_price: 100_000,
          current_price: 100_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      # Bid amount must be at least ₦1,000 higher for items ≥₦100k
      assert {:ok, _bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 101_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)
    end

    test "rejects bid when wallet balance < ₦5,000" do
      seller = create_user()
      buyer = create_user()

      # Insufficient wallet
      _wallet = create_wallet(user: buyer, balance: 3000)

      # Phone and ID verified
      _verification =
        create_verification(%{user: buyer, phone_verified: true, id_verified: true})

      item =
        create_item(%{
          title: "High Value Item",
          starting_price: 100_000,
          current_price: 100_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 101_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message, "₦5000") and String.contains?(err.message, "wallet")
             end)
    end

    test "rejects bid when ID not verified" do
      seller = create_user()
      buyer = create_user()

      # Sufficient wallet
      _wallet = create_wallet(user: buyer, balance: 6000)

      # Phone verified but ID NOT verified
      _verification =
        create_verification(%{user: buyer, phone_verified: true, id_verified: false})

      item =
        create_item(%{
          title: "High Value Item",
          starting_price: 100_000,
          current_price: 100_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 101_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message, "ID") and String.contains?(err.message, "verif")
             end)
    end
  end

  describe "handles missing wallet/verification gracefully" do
    test "rejects bid when user has no wallet" do
      seller = create_user()
      buyer = create_user()

      # No wallet created for buyer
      # Phone verified
      _verification = create_verification(%{user: buyer, phone_verified: true})

      item =
        create_item(%{
          title: "Item",
          starting_price: 10_000,
          current_price: 10_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 10_500,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message, "wallet")
             end)
    end

    test "rejects bid when user has no verification record" do
      seller = create_user()
      buyer = create_user()

      # Has wallet but no verification record
      _wallet = create_wallet(user: buyer, balance: 2000)

      item =
        create_item(%{
          title: "Item",
          starting_price: 10_000,
          current_price: 10_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 10_500,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors
             |> Enum.any?(fn err ->
               String.contains?(err.message, "verif") or
                 String.contains?(err.message, "phone")
             end)
    end
  end
end
