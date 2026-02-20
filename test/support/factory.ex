defmodule Angle.Factory do
  @moduledoc """
  Test factory for creating Ash resources with sensible defaults.

  All factory functions bypass authorization with `authorize?: false`
  so they can be used freely in tests without setting up actors/permissions.
  """

  @doc """
  Creates a user via the `register_with_password` action.

  ## Options

    * `:email` - defaults to a unique generated email
    * `:password` - defaults to "Password123!"
    * `:password_confirmation` - defaults to the value of `:password`

  Returns the created user (without the token metadata).
  """
  def create_user(attrs \\ %{}) do
    password = Map.get(attrs, :password, "Password123!")

    params =
      %{
        email: Map.get(attrs, :email, unique_email()),
        password: password,
        password_confirmation: Map.get(attrs, :password_confirmation, password)
      }
      |> maybe_put(:full_name, Map.get(attrs, :full_name))
      |> maybe_put(:phone_number, Map.get(attrs, :phone_number))

    user =
      Angle.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, params, authorize?: false)
      |> Ash.create!(authorize?: false)

    # Set profile fields not accepted by register_with_password
    profile_fields =
      %{}
      |> maybe_put(:username, Map.get(attrs, :username))
      |> maybe_put(:location, Map.get(attrs, :location))

    if profile_fields == %{} do
      user
    else
      user
      |> Ecto.Changeset.change(profile_fields)
      |> Angle.Repo.update!()
    end
  end

  @doc """
  Creates a role with the given attributes.

  ## Options

    * `:name` - defaults to a unique generated role name
    * `:description` - defaults to "Test role"
    * `:scope` - defaults to "global"
    * `:active` - defaults to true

  """
  def create_role(attrs \\ %{}) do
    params =
      %{
        name: Map.get(attrs, :name, "role_#{System.unique_integer([:positive])}"),
        description: Map.get(attrs, :description, "Test role"),
        scope: Map.get(attrs, :scope, "global"),
        active: Map.get(attrs, :active, true)
      }

    Ash.create!(Angle.Accounts.Role, params, authorize?: false)
  end

  @doc """
  Creates a category with the given attributes.

  ## Options

    * `:name` - defaults to a unique generated category name
    * `:description` - defaults to "Test category"
    * `:slug` - defaults to a unique generated slug

  """
  def create_category(attrs \\ %{}) do
    params =
      %{
        name: Map.get(attrs, :name, "category_#{System.unique_integer([:positive])}"),
        description: Map.get(attrs, :description, "Test category"),
        slug: Map.get(attrs, :slug, "cat-#{System.unique_integer([:positive])}")
      }
      |> maybe_put(:parent_id, Map.get(attrs, :parent_id))

    Ash.create!(Angle.Catalog.Category, params, authorize?: false)
  end

  @doc """
  Creates an item with the given attributes.

  Requires a user (as creator). If `:created_by_id` is not provided,
  a new user will be created.

  ## Options

    * `:title` - defaults to a unique generated title
    * `:description` - defaults to "Test item description"
    * `:starting_price` - defaults to Decimal.new("10.00")
    * `:created_by_id` - the UUID of the creator user (creates one if not provided)
    * `:category_id` - optional category UUID

  """
  def create_item(attrs \\ %{}) do
    created_by_id = Map.get_lazy(attrs, :created_by_id, fn -> create_user().id end)

    params =
      %{
        title: Map.get(attrs, :title, "Item #{System.unique_integer([:positive])}"),
        description: Map.get(attrs, :description, "Test item description"),
        starting_price: Map.get(attrs, :starting_price, Decimal.new("10.00")),
        created_by_id: created_by_id
      }
      |> maybe_put(:category_id, Map.get(attrs, :category_id))
      |> maybe_put(:slug, Map.get(attrs, :slug))
      |> maybe_put(:condition, Map.get(attrs, :condition))
      |> maybe_put(:sale_type, Map.get(attrs, :sale_type))
      |> maybe_put(:auction_status, Map.get(attrs, :auction_status))
      |> maybe_put(:end_time, Map.get(attrs, :end_time))
      |> maybe_put(:original_end_time, Map.get(attrs, :original_end_time))
      |> maybe_put(:extension_count, Map.get(attrs, :extension_count))

    Ash.create!(Angle.Inventory.Item, params, authorize?: false)
  end

  @doc """
  Creates a bid with the given attributes.

  Requires a user and an item. If not provided, they will be created.

  ## Options

    * `:amount` - defaults to Decimal.new("15.00")
    * `:bid_type` - defaults to :manual
    * `:item_id` - the UUID of the item (creates one if not provided)
    * `:user_id` - the UUID of the bidding user (creates one if not provided)

  """
  def create_bid(attrs \\ %{}) do
    user_id = Map.get_lazy(attrs, :user_id, fn -> create_user().id end)
    item_id = Map.get_lazy(attrs, :item_id, fn -> create_item().id end)

    params =
      %{
        amount: Map.get(attrs, :amount, Decimal.new("15.00")),
        bid_type: Map.get(attrs, :bid_type, :manual),
        item_id: item_id,
        user_id: user_id
      }

    Angle.Bidding.Bid
    |> Ash.Changeset.for_create(:create, params, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Creates a store profile for a user.

  ## Options

    * `:store_name` - defaults to a unique generated store name
    * `:contact_phone` - optional
    * `:whatsapp_link` - optional
    * `:location` - optional
    * `:address` - optional
    * `:delivery_preference` - defaults to "you_arrange"
    * `:user_id` - the UUID of the user (creates one if not provided)

  """
  def create_store_profile(attrs \\ %{}) do
    user_id = Map.get_lazy(attrs, :user_id, fn -> create_user().id end)

    params =
      %{
        store_name: Map.get(attrs, :store_name, "Store #{System.unique_integer([:positive])}"),
        user_id: user_id,
        delivery_preference: Map.get(attrs, :delivery_preference, "you_arrange")
      }
      |> maybe_put(:contact_phone, Map.get(attrs, :contact_phone))
      |> maybe_put(:whatsapp_link, Map.get(attrs, :whatsapp_link))
      |> maybe_put(:location, Map.get(attrs, :location))
      |> maybe_put(:address, Map.get(attrs, :address))

    Ash.create!(Angle.Accounts.StoreProfile, params, action: :upsert, authorize?: false)
  end

  @doc """
  Creates a payment method with the given attributes.

  Requires a user. If `:user` is not provided, a new user will be created.

  ## Options

    * `:card_type` - defaults to "visa"
    * `:last_four` - defaults to "5409"
    * `:exp_month` - defaults to "04"
    * `:exp_year` - defaults to "2025"
    * `:authorization_code` - defaults to a unique generated code
    * `:bank` - defaults to "TEST BANK"
    * `:paystack_reference` - defaults to a unique generated reference
    * `:is_default` - defaults to false
    * `:user` - the user record (creates one if not provided)

  """
  def create_payment_method(attrs \\ %{}) do
    user = attrs[:user] || create_user()

    params =
      %{
        card_type: Map.get(attrs, :card_type, "visa"),
        last_four: Map.get(attrs, :last_four, "5409"),
        exp_month: Map.get(attrs, :exp_month, "04"),
        exp_year: Map.get(attrs, :exp_year, "2025"),
        authorization_code: Map.get(attrs, :authorization_code, "AUTH_test_" <> random_string()),
        bank: Map.get(attrs, :bank, "TEST BANK"),
        paystack_reference: Map.get(attrs, :paystack_reference, "angle_test_" <> random_string()),
        is_default: Map.get(attrs, :is_default, false),
        user_id: user.id
      }

    Angle.Payments.PaymentMethod
    |> Ash.Changeset.for_create(:create, params, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Creates a payout method with the given attributes.

  Requires a user. If `:user` is not provided, a new user will be created.

  ## Options

    * `:bank_name` - defaults to "Kuda Bank"
    * `:bank_code` - defaults to "090267"
    * `:account_number` - defaults to "2009568002"
    * `:account_name` - defaults to "Test User"
    * `:recipient_code` - defaults to a unique generated code
    * `:is_default` - defaults to false
    * `:user` - the user record (creates one if not provided)

  """
  def create_payout_method(attrs \\ %{}) do
    user = attrs[:user] || create_user()

    params =
      %{
        bank_name: Map.get(attrs, :bank_name, "Kuda Bank"),
        bank_code: Map.get(attrs, :bank_code, "090267"),
        account_number: Map.get(attrs, :account_number, "2009568002"),
        account_name: Map.get(attrs, :account_name, "Test User"),
        recipient_code: Map.get(attrs, :recipient_code, "RCP_test_" <> random_string()),
        is_default: Map.get(attrs, :is_default, false),
        user_id: user.id
      }

    Angle.Payments.PayoutMethod
    |> Ash.Changeset.for_create(:create, params, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Creates a watchlist item (adds an item to a user's watchlist).

  ## Options

    * `:user` - the user record (creates one if not provided)
    * `:item` - the item record (creates one if not provided)

  """
  def create_watchlist_item(opts \\ []) do
    user = Keyword.get_lazy(opts, :user, fn -> create_user() end)
    item = Keyword.get_lazy(opts, :item, fn -> create_item() end)

    Angle.Inventory.WatchlistItem
    |> Ash.Changeset.for_create(:add, %{item_id: item.id}, actor: user, authorize?: false)
    |> Ash.create!()
  end

  @doc """
  Creates an order with the given attributes.

  Requires a buyer, seller, and item. If not provided, they will be created.

  ## Options

    * `:amount` - defaults to Decimal.new("100.00")
    * `:buyer` - the buyer user record (creates one if not provided)
    * `:seller` - the seller user record (creates one if not provided)
    * `:item` - the item record (creates one owned by seller if not provided)

  """
  def create_order(attrs \\ %{}) do
    buyer = attrs[:buyer] || create_user()
    seller = attrs[:seller] || create_user()
    item = attrs[:item] || create_item(%{created_by_id: seller.id})

    params = %{
      amount: Map.get(attrs, :amount, Decimal.new("100.00")),
      item_id: item.id,
      buyer_id: buyer.id,
      seller_id: seller.id
    }

    Angle.Bidding.Order
    |> Ash.Changeset.for_create(:create, params, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Creates a review for a completed order.

  Completes the order if it isn't already, then creates the review.

  ## Options

    * `:order` - the order to review (required)
    * `:buyer` - the buyer user (required, must be the order's buyer)
    * `:rating` - defaults to 5
    * `:comment` - optional

  """
  def create_review(attrs \\ %{}) do
    order = attrs[:order] || raise "create_review requires :order"
    buyer = attrs[:buyer] || raise "create_review requires :buyer"

    # Complete the order if not already completed
    order =
      if order.status != :completed do
        order
        |> Ash.Changeset.for_update(
          :pay_order,
          %{payment_reference: "PAY_#{System.unique_integer([:positive])}"},
          authorize?: false
        )
        |> Ash.update!()
        |> Ash.Changeset.for_update(:mark_dispatched, %{}, authorize?: false)
        |> Ash.update!()
        |> Ash.Changeset.for_update(:confirm_receipt, %{}, authorize?: false)
        |> Ash.update!()
      else
        order
      end

    params = %{
      order_id: order.id,
      rating: Map.get(attrs, :rating, 5),
      comment: Map.get(attrs, :comment)
    }

    Angle.Bidding.Review
    |> Ash.Changeset.for_create(:create, params, actor: buyer)
    |> Ash.create!()
  end

  @doc """
  Creates a user interest record.

  ## Options

    * `:user_id` - the UUID of the user (creates one if not provided)
    * `:category_id` - the UUID of the category (creates one if not provided)
    * `:interest_score` - defaults to 0.5
    * `:last_interaction_at` - defaults to current time
    * `:interaction_count` - defaults to 1

  """
  def create_interest(attrs \\ %{}) do
    user_id = Map.get_lazy(attrs, :user_id, fn -> create_user().id end)
    category_id = Map.get_lazy(attrs, :category_id, fn -> create_category().id end)

    params = %{
      user_id: user_id,
      category_id: category_id,
      interest_score: Map.get(attrs, :interest_score, 0.5),
      last_interaction_at: Map.get(attrs, :last_interaction_at, DateTime.utc_now()),
      interaction_count: Map.get(attrs, :interaction_count, 1)
    }

    Angle.Recommendations.UserInterest
    |> Ash.Changeset.for_create(:create, params, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Creates an item similarity record.

  ## Options

    * `:source_item_id` - the UUID of the source item (creates one if not provided)
    * `:similar_item_id` - the UUID of the similar item (creates one if not provided)
    * `:similarity_score` - defaults to 0.8
    * `:reason` - defaults to :same_category

  """
  def create_similarity(attrs \\ %{}) do
    source_item_id = Map.get_lazy(attrs, :source_item_id, fn -> create_item().id end)
    similar_item_id = Map.get_lazy(attrs, :similar_item_id, fn -> create_item().id end)

    params = %{
      source_item_id: source_item_id,
      similar_item_id: similar_item_id,
      similarity_score: Map.get(attrs, :similarity_score, 0.8),
      reason: Map.get(attrs, :reason, :same_category)
    }

    Angle.Recommendations.ItemSimilarity
    |> Ash.Changeset.for_create(:create, params, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Creates a recommended item record.

  ## Options

    * `:user_id` - the UUID of the user (creates one if not provided)
    * `:item_id` - the UUID of the item (creates one if not provided)
    * `:recommendation_score` - defaults to 0.9
    * `:recommendation_reason` - defaults to "Based on your interests"
    * `:rank` - defaults to 1
    * `:generated_at` - defaults to current time

  """
  def create_recommendation(attrs \\ %{}) do
    user_id = Map.get_lazy(attrs, :user_id, fn -> create_user().id end)
    item_id = Map.get_lazy(attrs, :item_id, fn -> create_item().id end)

    params = %{
      user_id: user_id,
      item_id: item_id,
      recommendation_score: Map.get(attrs, :recommendation_score, 0.9),
      recommendation_reason: Map.get(attrs, :recommendation_reason, "Based on your interests"),
      rank: Map.get(attrs, :rank, 1),
      generated_at: Map.get(attrs, :generated_at, DateTime.utc_now())
    }

    Angle.Recommendations.RecommendedItem
    |> Ash.Changeset.for_create(:create, params, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Creates a user verification record.

  ## Options

    * `:user` - the user record (required)

  """
  def create_verification(attrs \\ %{}) do
    user = attrs[:user] || raise "create_verification requires :user"

    params = %{
      user_id: user.id
    }

    Angle.Accounts.UserVerification
    |> Ash.Changeset.for_create(:create, params, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Alias for create_user/1 - for tests that use bidder terminology.
  """
  def create_bidder(attrs \\ %{}), do: create_user(attrs)

  @doc """
  Fetches the auto-created wallet for a user and optionally sets a balance.

  Wallets are automatically created during user registration, so this function
  retrieves the existing wallet instead of creating a new one.

  ## Options

    * `:user` - the user record (required)
    * `:balance` - optional balance to set (defaults to existing balance)

  """
  def create_wallet(opts \\ []) do
    user = Keyword.get(opts, :user) || raise "create_wallet requires :user"
    balance = Keyword.get(opts, :balance)

    require Ash.Query

    # Wallet is automatically created by registration hook
    wallet =
      Angle.Payments.UserWallet
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read_one!(authorize?: false)

    # If balance is provided, update the wallet
    if balance do
      wallet
      |> Ecto.Changeset.change(%{balance: Decimal.new(to_string(balance))})
      |> Angle.Repo.update!()
    else
      wallet
    end
  end

  # Helpers

  defp unique_email do
    "user_#{System.unique_integer([:positive])}@example.com"
  end

  defp random_string do
    Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
