# priv/repo/seeds/option_sets_and_schemas.exs
#
# Run: mix run priv/repo/seeds/option_sets_and_schemas.exs
#
# Creates option sets with values, then populates attribute_schema
# for existing categories. Safe to run multiple times.

alias Angle.Catalog.{Category, OptionSet}

require Ash.Query

# ── Part 1: Seed option sets ──────────────────────────────────────────

option_sets = [
  %{
    name: "Phone Storage",
    slug: "phone-storage",
    description: "Storage capacity options for smartphones",
    values: [
      %{value: "32GB", label: "32GB", sort_order: 1},
      %{value: "64GB", label: "64GB", sort_order: 2},
      %{value: "128GB", label: "128GB", sort_order: 3},
      %{value: "256GB", label: "256GB", sort_order: 4},
      %{value: "512GB", label: "512GB", sort_order: 5},
      %{value: "1TB", label: "1TB", sort_order: 6}
    ]
  },
  %{
    name: "Laptop RAM",
    slug: "laptop-ram",
    description: "RAM options for laptops",
    values: [
      %{value: "4GB", label: "4GB", sort_order: 1},
      %{value: "8GB", label: "8GB", sort_order: 2},
      %{value: "16GB", label: "16GB", sort_order: 3},
      %{value: "32GB", label: "32GB", sort_order: 4},
      %{value: "64GB", label: "64GB", sort_order: 5}
    ]
  },
  %{
    name: "Laptop Storage",
    slug: "laptop-storage",
    description: "Storage options for laptops",
    values: [
      %{value: "128GB SSD", label: "128GB SSD", sort_order: 1},
      %{value: "256GB SSD", label: "256GB SSD", sort_order: 2},
      %{value: "512GB SSD", label: "512GB SSD", sort_order: 3},
      %{value: "1TB SSD", label: "1TB SSD", sort_order: 4},
      %{value: "2TB SSD", label: "2TB SSD", sort_order: 5},
      %{value: "1TB HDD", label: "1TB HDD", sort_order: 6}
    ]
  },
  %{
    name: "Screen Size",
    slug: "screen-size",
    description: "Screen size options",
    values: [
      %{value: ~s(13"), label: ~s(13"), sort_order: 1},
      %{value: ~s(14"), label: ~s(14"), sort_order: 2},
      %{value: ~s(15"), label: ~s(15"), sort_order: 3},
      %{value: ~s(16"), label: ~s(16"), sort_order: 4},
      %{value: ~s(17"), label: ~s(17"), sort_order: 5}
    ]
  },
  %{
    name: "Item Condition Grade",
    slug: "condition-grade",
    description: "Detailed condition grades for collectibles",
    values: [
      %{value: "Mint", label: "Mint", sort_order: 1},
      %{value: "Near Mint", label: "Near Mint", sort_order: 2},
      %{value: "Excellent", label: "Excellent", sort_order: 3},
      %{value: "Very Good", label: "Very Good", sort_order: 4},
      %{value: "Good", label: "Good", sort_order: 5},
      %{value: "Fair", label: "Fair", sort_order: 6},
      %{value: "Poor", label: "Poor", sort_order: 7}
    ]
  },
  %{
    name: "Clothing Size",
    slug: "clothing-size",
    description: "Standard clothing sizes",
    values: [
      %{value: "XS", label: "XS", sort_order: 1},
      %{value: "S", label: "S", sort_order: 2},
      %{value: "M", label: "M", sort_order: 3},
      %{value: "L", label: "L", sort_order: 4},
      %{value: "XL", label: "XL", sort_order: 5},
      %{value: "XXL", label: "XXL", sort_order: 6}
    ]
  },
  %{
    name: "Shoe Size (US)",
    slug: "shoe-size-us",
    description: "US shoe sizes",
    values: [
      %{value: "6", label: "US 6", sort_order: 1},
      %{value: "7", label: "US 7", sort_order: 2},
      %{value: "8", label: "US 8", sort_order: 3},
      %{value: "9", label: "US 9", sort_order: 4},
      %{value: "10", label: "US 10", sort_order: 5},
      %{value: "11", label: "US 11", sort_order: 6},
      %{value: "12", label: "US 12", sort_order: 7},
      %{value: "13", label: "US 13", sort_order: 8}
    ]
  },
  %{
    name: "Gaming Storage",
    slug: "gaming-storage",
    description: "Storage options for gaming consoles",
    values: [
      %{value: "256GB", label: "256GB", sort_order: 1},
      %{value: "512GB", label: "512GB", sort_order: 2},
      %{value: "825GB", label: "825GB", sort_order: 3},
      %{value: "1TB", label: "1TB", sort_order: 4},
      %{value: "2TB", label: "2TB", sort_order: 5}
    ]
  }
]

for os <- option_sets do
  case OptionSet
       |> Ash.Query.filter(slug == ^os.slug)
       |> Ash.read_one(authorize?: false) do
    {:ok, nil} ->
      OptionSet
      |> Ash.Changeset.for_create(
        :create_with_values,
        %{
          name: os.name,
          slug: os.slug,
          description: os.description,
          values: os.values
        },
        authorize?: false
      )
      |> Ash.create!()

      IO.puts("Created option set: #{os.name}")

    {:ok, _existing} ->
      IO.puts("Option set already exists, skipping: #{os.name}")

    _ ->
      IO.puts("Error checking option set: #{os.name}")
  end
end

# ── Part 2: Seed category attribute_schema ────────────────────────────
#
# Now that attribute_schema is {:array, CategoryField}, we pass a flat
# list of maps. Each field can use:
#   - option_set_slug: lazy-loaded dropdown from OptionSet RPC
#   - options: inline dropdown (no network call)
#   - neither: free text input
#   - description: helper text shown below the field

schemas = %{
  "Smartphones" => [
    %{name: "Model", type: "string", required: true, description: "e.g. iPhone 15 Pro Max"},
    %{name: "Storage", type: "string", option_set_slug: "phone-storage"},
    %{
      name: "Color",
      type: "string",
      options: ["Black", "White", "Blue", "Red", "Gold", "Silver", "Green", "Purple"]
    },
    %{name: "Display", type: "string", description: ~s(e.g. 6.7" Super Retina XDR)},
    %{name: "Chip", type: "string", description: "e.g. A17 Pro"},
    %{name: "Camera", type: "string", description: "e.g. 48MP Triple"},
    %{name: "Battery", type: "string", description: "e.g. 4422 mAh"}
  ],
  "Laptops" => [
    %{
      name: "Brand & Model",
      type: "string",
      required: true,
      description: ~s(e.g. MacBook Pro 16")
    },
    %{name: "Processor", type: "string", description: "e.g. Apple M3 Pro, Intel i7-13700H"},
    %{name: "RAM", type: "string", option_set_slug: "laptop-ram"},
    %{name: "Storage", type: "string", option_set_slug: "laptop-storage"},
    %{name: "Screen Size", type: "string", option_set_slug: "screen-size"},
    %{name: "Graphics", type: "string", description: "e.g. Integrated, RTX 4060"}
  ],
  "Audio & Headphones" => [
    %{name: "Brand & Model", type: "string", required: true},
    %{
      name: "Type",
      type: "string",
      options: ["Over-ear", "On-ear", "In-ear", "Earbuds", "Speaker", "Soundbar"]
    },
    %{name: "Connectivity", type: "string", options: ["Wired", "Bluetooth", "Wired + Bluetooth"]},
    %{name: "Driver Size", type: "string"}
  ],
  "Gaming" => [
    %{
      name: "Console/Accessory",
      type: "string",
      required: true,
      options: [
        "PlayStation 5",
        "Xbox Series X",
        "Xbox Series S",
        "Nintendo Switch",
        "Steam Deck",
        "Controller",
        "Headset",
        "Other"
      ]
    },
    %{name: "Model", type: "string"},
    %{name: "Storage", type: "string", option_set_slug: "gaming-storage"},
    %{
      name: "Included Accessories",
      type: "string",
      description: "e.g. 2 controllers, charging dock"
    }
  ],
  "Cameras" => [
    %{name: "Brand & Model", type: "string", required: true},
    %{
      name: "Type",
      type: "string",
      options: ["DSLR", "Mirrorless", "Point & Shoot", "Action Camera", "Film Camera"]
    },
    %{name: "Megapixels", type: "string"},
    %{name: "Lens Mount", type: "string", description: "e.g. Canon RF, Sony E, Nikon Z"}
  ],
  "Men's Clothing" => [
    %{
      name: "Type",
      type: "string",
      required: true,
      options: [
        "Shirt",
        "T-Shirt",
        "Trousers",
        "Jeans",
        "Jacket",
        "Suit",
        "Agbada",
        "Kaftan",
        "Other"
      ]
    },
    %{name: "Size", type: "string", option_set_slug: "clothing-size"},
    %{name: "Material", type: "string"},
    %{name: "Brand", type: "string"}
  ],
  "Women's Clothing" => [
    %{
      name: "Type",
      type: "string",
      required: true,
      options: ["Dress", "Blouse", "Skirt", "Trousers", "Gown", "Iro & Buba", "Ankara", "Other"]
    },
    %{name: "Size", type: "string", option_set_slug: "clothing-size"},
    %{name: "Material", type: "string"},
    %{name: "Brand", type: "string"}
  ],
  "Shoes" => [
    %{name: "Brand & Model", type: "string", required: true},
    %{name: "Size", type: "string", option_set_slug: "shoe-size-us"},
    %{name: "Color", type: "string"},
    %{
      name: "Material",
      type: "string",
      options: ["Leather", "Suede", "Canvas", "Synthetic", "Mesh", "Other"]
    }
  ],
  "Watches" => [
    %{name: "Brand & Model", type: "string", required: true},
    %{
      name: "Movement",
      type: "string",
      options: ["Automatic", "Quartz", "Manual", "Solar", "Smartwatch"]
    },
    %{name: "Case Size", type: "string", description: "e.g. 42mm"},
    %{
      name: "Material",
      type: "string",
      options: ["Stainless Steel", "Gold", "Titanium", "Ceramic", "Plastic"]
    }
  ],
  "Coins & Currency" => [
    %{
      name: "Type",
      type: "string",
      required: true,
      options: ["Coin", "Banknote", "Token", "Medal"]
    },
    %{name: "Year/Period", type: "string"},
    %{name: "Country of Origin", type: "string"},
    %{name: "Grade", type: "string", option_set_slug: "condition-grade"}
  ],
  "Trading Cards" => [
    %{name: "Card Name", type: "string", required: true},
    %{name: "Set/Series", type: "string"},
    %{name: "Grade", type: "string", option_set_slug: "condition-grade"},
    %{name: "Year", type: "string"}
  ],
  "Antiques" => [
    %{name: "Item Type", type: "string", required: true},
    %{name: "Origin", type: "string"},
    %{name: "Age/Period", type: "string"},
    %{name: "Material", type: "string"}
  ],
  "Paintings" => [
    %{name: "Artist", type: "string"},
    %{
      name: "Medium",
      type: "string",
      options: ["Oil", "Acrylic", "Watercolor", "Pastel", "Mixed Media", "Digital Print"]
    },
    %{name: "Dimensions", type: "string", description: ~s(e.g. 24" x 36")},
    %{name: "Year", type: "string"}
  ],
  "Sculptures" => [
    %{name: "Artist", type: "string"},
    %{
      name: "Material",
      type: "string",
      required: true,
      options: ["Bronze", "Wood", "Stone", "Clay", "Metal", "Mixed Media"]
    },
    %{name: "Dimensions", type: "string", description: "Height x Width x Depth"},
    %{name: "Weight", type: "string"}
  ],
  "Cars" => [
    %{
      name: "Make & Model",
      type: "string",
      required: true,
      description: "e.g. Toyota Camry 2020"
    },
    %{name: "Year", type: "string", required: true},
    %{name: "Mileage", type: "string", description: "e.g. 45,000 km"},
    %{name: "Transmission", type: "string", options: ["Automatic", "Manual", "CVT"]},
    %{
      name: "Fuel Type",
      type: "string",
      options: ["Petrol", "Diesel", "Electric", "Hybrid", "CNG"]
    }
  ],
  "Motorcycles" => [
    %{name: "Make & Model", type: "string", required: true},
    %{name: "Year", type: "string"},
    %{name: "Engine Size", type: "string", description: "e.g. 650cc"},
    %{name: "Mileage", type: "string"}
  ]
}

# Update categories that exist in the DB
for {name, fields} <- schemas do
  case Category
       |> Ash.Query.filter(name == ^name)
       |> Ash.read_one(authorize?: false) do
    {:ok, %Category{} = cat} ->
      cat
      |> Ash.Changeset.for_update(:update, %{attribute_schema: fields}, authorize?: false)
      |> Ash.update!()

      IO.puts("Updated attribute_schema for: #{name}")

    _ ->
      IO.puts("Category not found, skipping: #{name}")
  end
end

IO.puts("\nDone seeding option sets and category schemas.")
