defmodule Angle.Bidding.Bid.ValidateWalletCommitment do
  @moduledoc """
  Validates that the bidder has sufficient wallet balance and verification
  level based on the item's price tier.

  Requirements:
  - <₦50k items: ₦1,000 wallet + phone verified
  - ≥₦50k items: ₦5,000 wallet + phone + ID verified

  The wallet acts as a commitment signal - funds are NOT locked during bidding.
  After winning, payment is collected separately.
  """
  use Ash.Resource.Change

  require Ash.Query

  # Tier thresholds
  @high_value_threshold Decimal.new("50000")
  @low_tier_wallet_min Decimal.new("1000")
  @high_tier_wallet_min Decimal.new("5000")

  @impl true
  def change(changeset, _opts, _context) do
    validate_commitment(changeset)
  end

  defp validate_commitment(changeset) do
    # Get user_id from changeset attribute (set by action)
    user_id = Ash.Changeset.get_attribute(changeset, :user_id)

    if is_nil(user_id) do
      Ash.Changeset.add_error(changeset, message: "Must be logged in to bid")
    else
      # Get item to check price
      item_id = Ash.Changeset.get_attribute(changeset, :item_id)

      item =
        Angle.Inventory.Item
        |> Ash.Query.filter(id == ^item_id)
        |> Ash.Query.select([:current_price, :starting_price])
        |> Ash.read_one!(authorize?: false)

      # Determine price (use current_price if set, else starting_price)
      price = item.current_price || item.starting_price

      # Determine tier requirements
      is_high_value = Decimal.compare(price, @high_value_threshold) != :lt

      required_wallet =
        if is_high_value, do: @high_tier_wallet_min, else: @low_tier_wallet_min

      requires_id = is_high_value

      # Load user's wallet
      wallet =
        Angle.Payments.UserWallet
        |> Ash.Query.filter(user_id == ^user_id)
        |> Ash.read_one(authorize?: false)

      # Load user's verification
      verification =
        Angle.Accounts.UserVerification
        |> Ash.Query.filter(user_id == ^user_id)
        |> Ash.read_one(authorize?: false)

      # Validate - unpack wallet and verification first
      case {wallet, verification} do
        {{:ok, nil}, _} ->
          # No wallet found
          Ash.Changeset.add_error(
            changeset,
            message:
              "You must create a wallet before bidding. Visit your account settings to set up your wallet."
          )

        {{:error, _}, _} ->
          # Error loading wallet
          Ash.Changeset.add_error(
            changeset,
            message:
              "You must create a wallet before bidding. Visit your account settings to set up your wallet."
          )

        {_, {:ok, nil}} ->
          # No verification found
          Ash.Changeset.add_error(
            changeset,
            message:
              "You must verify your phone number before bidding. Visit your account settings to verify."
          )

        {_, {:error, _}} ->
          # Error loading verification
          Ash.Changeset.add_error(
            changeset,
            message:
              "You must verify your phone number before bidding. Visit your account settings to verify."
          )

        {{:ok, wallet}, {:ok, verification}} ->
          # Both wallet and verification exist, now validate them
          changeset
          |> validate_wallet_balance(wallet, required_wallet)
          |> validate_phone_verified(verification)
          |> validate_id_verified_if_required(verification, requires_id, price)
      end
    end
  end

  defp validate_wallet_balance(changeset, wallet, required_amount) do
    if Decimal.compare(wallet.balance, required_amount) == :lt do
      Ash.Changeset.add_error(
        changeset,
        message:
          "Minimum wallet balance of ₦#{Decimal.to_string(required_amount)} required. Current balance: ₦#{Decimal.to_string(wallet.balance)}. Please deposit funds to continue."
      )
    else
      changeset
    end
  end

  defp validate_phone_verified(changeset, verification) do
    if verification.phone_verified do
      changeset
    else
      Ash.Changeset.add_error(
        changeset,
        message:
          "You must verify your phone number before bidding. Visit your account settings to verify."
      )
    end
  end

  defp validate_id_verified_if_required(changeset, verification, true, price) do
    # High-value item, ID required
    if verification.id_verified do
      changeset
    else
      Ash.Changeset.add_error(
        changeset,
        message:
          "Items ≥₦50,000 require ID verification. This item is ₦#{Decimal.to_string(price)}. Please upload your ID document for verification."
      )
    end
  end

  defp validate_id_verified_if_required(changeset, _verification, false, _price) do
    # Low-value item, ID not required
    changeset
  end
end
