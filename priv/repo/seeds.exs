# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Angle.Repo.insert!(%Angle.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Angle.Accounts.Role
alias Angle.Accounts

# Create standard roles for the auction platform
roles_to_create = [
  %{
    name: "admin",
    description: "Full system access including user management and content moderation",
    scope: "global",
    active: true
  },
  %{
    name: "seller",
    description: "Can create and manage auction listings",
    scope: "global",
    active: true
  },
  %{
    name: "user",
    description: "Can place bids and participate in auctions",
    scope: "global",
    active: true
  },
  %{
    name: "viewer",
    description: "Read-only access to public auction content",
    scope: "global",
    active: true
  }
]

# Create roles if they don't exist
Enum.each(roles_to_create, fn role_attrs ->
  case Ash.get(Role, %{name: role_attrs.name}, domain: Accounts) do
    {:ok, _existing_role} ->
      IO.puts("Role '#{role_attrs.name}' already exists, skipping...")

    {:error, _} ->
      case Ash.create(Role, role_attrs, domain: Accounts) do
        {:ok, role} ->
          IO.puts("✅ Created role: #{role.name} - #{role.description}")

        {:error, error} ->
          IO.puts("❌ Failed to create role '#{role_attrs.name}': #{inspect(error)}")
      end
  end
end)

IO.puts("\n🎉 Roles seeding completed!")

# Create comprehensive permissions for the auction platform
alias Angle.Accounts.{Permission, RolePermission}

permissions_to_create = [
  # User Management Permissions
  %{
    name: "manage_users",
    resource: "user",
    action: "all",
    scope: "system",
    description: "Full user management including creation, updates, and role assignments"
  },
  %{
    name: "read_users",
    resource: "user",
    action: "read",
    scope: "system",
    description: "View user profiles and information"
  },

  # Item/Listing Management Permissions
  %{
    name: "create_items",
    resource: "item",
    action: "create",
    scope: "own",
    description: "Create new auction listings"
  },
  %{
    name: "update_own_items",
    resource: "item",
    action: "update",
    scope: "own",
    description: "Update own auction listings"
  },
  %{
    name: "delete_own_items",
    resource: "item",
    action: "delete",
    scope: "own",
    description: "Delete own auction listings"
  },
  %{
    name: "manage_all_items",
    resource: "item",
    action: "all",
    scope: "system",
    description: "Full item management across all users (admin only)"
  },
  %{
    name: "publish_items",
    resource: "item",
    action: "publish",
    scope: "own",
    description: "Publish auction items to make them public"
  },

  # Bidding Permissions
  %{
    name: "place_bids",
    resource: "bid",
    action: "create",
    scope: "own",
    description: "Place bids on auction items"
  },
  %{
    name: "view_bids",
    resource: "bid",
    action: "read",
    scope: "system",
    description: "View bidding activity on auction items"
  },
  %{
    name: "manage_bids",
    resource: "bid",
    action: "all",
    scope: "system",
    description: "Manage all bidding activity (admin only)"
  },

  # Catalog Management Permissions
  %{
    name: "read_catalog",
    resource: "catalog",
    action: "read",
    scope: "system",
    description: "Browse catalog items and categories"
  },
  %{
    name: "manage_catalog",
    resource: "catalog",
    action: "all",
    scope: "system",
    description: "Full catalog management including categories and option sets"
  },

  # Role and Permission Management
  %{
    name: "manage_roles",
    resource: "role",
    action: "all",
    scope: "system",
    description: "Create and manage user roles"
  },
  %{
    name: "manage_permissions",
    resource: "permission",
    action: "all",
    scope: "system",
    description: "Manage permissions and role assignments"
  }
]

# Create permissions if they don't exist
IO.puts("\n📝 Creating permissions...")

created_permissions =
  Enum.map(permissions_to_create, fn permission_attrs ->
    case Ash.get(Permission, %{name: permission_attrs.name}, domain: Accounts) do
      {:ok, existing_permission} ->
        IO.puts("Permission '#{permission_attrs.name}' already exists, skipping...")
        existing_permission

      {:error, _} ->
        case Ash.create(Permission, permission_attrs, domain: Accounts, authorize?: false) do
          {:ok, permission} ->
            IO.puts("✅ Created permission: #{permission.name} - #{permission.description}")
            permission

          {:error, error} ->
            IO.puts("❌ Failed to create permission '#{permission_attrs.name}': #{inspect(error)}")
            nil
        end
    end
  end)
  |> Enum.filter(& &1)

# Assign permissions to roles
IO.puts("\n🔗 Assigning permissions to roles...")

# Get all roles
all_roles = Role |> Ash.read!(domain: Accounts, authorize?: false)
role_map = Enum.into(all_roles, %{}, fn role -> {role.name, role} end)

# Define role-permission mappings
role_permission_mappings = %{
  "admin" => [
    "manage_users",
    "read_users",
    "manage_all_items",
    "manage_bids",
    "manage_catalog",
    "manage_roles",
    "manage_permissions"
  ],
  "seller" => [
    "create_items",
    "update_own_items",
    "delete_own_items",
    "publish_items",
    "view_bids",
    "read_catalog"
  ],
  "user" => [
    "place_bids",
    "view_bids",
    "read_catalog"
  ],
  "viewer" => [
    "read_catalog"
  ]
}

# Create role-permission assignments
Enum.each(role_permission_mappings, fn {role_name, permission_names} ->
  role = Map.get(role_map, role_name)

  if role do
    IO.puts("Assigning permissions to #{role_name}...")

    Enum.each(permission_names, fn permission_name ->
      permission = Enum.find(created_permissions, fn p -> p.name == permission_name end)

      if permission do
        case Ash.create(RolePermission, %{role_id: role.id, permission_id: permission.id},
               domain: Accounts,
               authorize?: false
             ) do
          {:ok, _} ->
            IO.puts("  ✅ #{role_name} -> #{permission_name}")

          {:error, _} ->
            IO.puts("  ⚠️  #{role_name} -> #{permission_name} (already exists or failed)")
        end
      end
    end)
  end
end)

IO.puts("\n🎉 Permission system seeding completed!")

# Seed categories and subcategories
alias Angle.Catalog.Category

IO.puts("\n📂 Creating categories...")

categories_with_subcategories = [
  {"Electronics", "electronics",
   [
     {"Smartphones", "smartphones"},
     {"Laptops", "laptops"},
     {"Audio & Headphones", "audio-headphones"},
     {"Gaming", "gaming"},
     {"Cameras", "cameras"}
   ]},
  {"Fashion", "fashion",
   [
     {"Men's Clothing", "mens-clothing"},
     {"Women's Clothing", "womens-clothing"},
     {"Shoes", "shoes"},
     {"Bags & Accessories", "bags-accessories"},
     {"Watches", "watches"}
   ]},
  {"Art", "art",
   [
     {"Paintings", "paintings"},
     {"Sculptures", "sculptures"},
     {"Photography", "photography"},
     {"Digital Art", "digital-art"}
   ]},
  {"Vehicles", "vehicles",
   [
     {"Cars", "cars"},
     {"Motorcycles", "motorcycles"},
     {"Boats", "boats"},
     {"Parts & Accessories", "parts-accessories"}
   ]},
  {"Collectibles", "collectibles",
   [
     {"Coins & Currency", "coins-currency"},
     {"Trading Cards", "trading-cards"},
     {"Stamps", "stamps"},
     {"Memorabilia", "memorabilia"},
     {"Antiques", "antiques"}
   ]},
  {"Jewelry", "jewelry",
   [
     {"Rings", "rings"},
     {"Necklaces", "necklaces"},
     {"Bracelets", "bracelets"},
     {"Earrings", "earrings"}
   ]},
  {"Furniture", "furniture",
   [
     {"Living Room", "living-room"},
     {"Bedroom", "bedroom"},
     {"Office", "office"},
     {"Outdoor", "outdoor"}
   ]},
  {"Sports", "sports",
   [
     {"Fitness Equipment", "fitness-equipment"},
     {"Outdoor Sports", "outdoor-sports"},
     {"Team Sports", "team-sports"},
     {"Cycling", "cycling"}
   ]}
]

Enum.each(categories_with_subcategories, fn {name, slug, subcategories} ->
  parent =
    case Ash.get(Category, %{slug: slug}, domain: Angle.Catalog, authorize?: false) do
      {:ok, existing} ->
        IO.puts("Category '#{name}' already exists, skipping...")
        existing

      {:error, _} ->
        case Ash.create(Category, %{name: name, slug: slug},
               domain: Angle.Catalog,
               authorize?: false
             ) do
          {:ok, category} ->
            IO.puts("✅ Created category: #{name}")
            category

          {:error, error} ->
            IO.puts("❌ Failed to create category '#{name}': #{inspect(error)}")
            nil
        end
    end

  if parent do
    Enum.each(subcategories, fn {sub_name, sub_slug} ->
      case Ash.get(Category, %{slug: sub_slug}, domain: Angle.Catalog, authorize?: false) do
        {:ok, _existing} ->
          IO.puts("  Subcategory '#{sub_name}' already exists, skipping...")

        {:error, _} ->
          case Ash.create(Category, %{name: sub_name, slug: sub_slug, parent_id: parent.id},
                 domain: Angle.Catalog,
                 authorize?: false
               ) do
            {:ok, _} ->
              IO.puts("  ✅ Created subcategory: #{sub_name}")

            {:error, error} ->
              IO.puts("  ❌ Failed to create subcategory '#{sub_name}': #{inspect(error)}")
          end
      end
    end)
  end
end)

IO.puts("\n🎉 Category seeding completed!")
