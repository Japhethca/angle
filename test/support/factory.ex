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

    Ash.create!(Angle.Bidding.Bid, params, authorize?: false)
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

  # Helpers

  defp unique_email do
    "user_#{System.unique_integer([:positive])}@example.com"
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
