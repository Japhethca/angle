# priv/repo/seeds/nigerian_locations.exs
#
# Run: mix run priv/repo/seeds/nigerian_locations.exs
#
# Creates Nigerian states and LGAs as hierarchical option sets.
# Safe to run multiple times (idempotent).

alias Angle.Catalog.OptionSet

require Ash.Query

IO.puts("\n🇳🇬 Seeding Nigerian States and LGAs...\n")

# ── Nigerian States (Parent Option Set) ──────────────────────────────

states_data = %{
  name: "Nigerian States",
  slug: "ng-states",
  description: "States and FCT in Nigeria",
  values: [
    %{value: "abia", label: "Abia", sort_order: 1},
    %{value: "lagos", label: "Lagos", sort_order: 2},
    %{value: "fct", label: "Federal Capital Territory", sort_order: 3}
  ]
}

states_option_set =
  case OptionSet
       |> Ash.Query.filter(slug == ^states_data.slug)
       |> Ash.read_one(authorize?: false) do
    {:ok, nil} ->
      states_os =
        OptionSet
        |> Ash.Changeset.for_create(
          :create_with_values,
          %{
            name: states_data.name,
            slug: states_data.slug,
            description: states_data.description,
            values: states_data.values
          },
          authorize?: false
        )
        |> Ash.create!()

      IO.puts("✓ Created parent option set: #{states_data.name}")
      states_os

    {:ok, existing} ->
      IO.puts("⊙ Parent option set already exists, skipping: #{states_data.name}")
      existing

    _ ->
      IO.puts("✗ Error checking parent option set: #{states_data.name}")
      nil
  end

# ── Nigerian LGAs (Child Option Sets) ────────────────────────────────

lgas_by_state = %{
  "abia" => %{
    name: "Abia LGAs",
    slug: "ng-lgas-abia",
    description: "Local Government Areas in Abia State",
    values: [
      %{value: "aba-north", label: "Aba North", parent_value: "abia", sort_order: 1},
      %{value: "aba-south", label: "Aba South", parent_value: "abia", sort_order: 2},
      %{value: "arochukwu", label: "Arochukwu", parent_value: "abia", sort_order: 3},
      %{value: "bende", label: "Bende", parent_value: "abia", sort_order: 4},
      %{value: "ikwuano", label: "Ikwuano", parent_value: "abia", sort_order: 5},
      %{
        value: "isiala-ngwa-north",
        label: "Isiala Ngwa North",
        parent_value: "abia",
        sort_order: 6
      },
      %{
        value: "isiala-ngwa-south",
        label: "Isiala Ngwa South",
        parent_value: "abia",
        sort_order: 7
      },
      %{value: "isuikwuato", label: "Isuikwuato", parent_value: "abia", sort_order: 8},
      %{value: "obi-ngwa", label: "Obi Ngwa", parent_value: "abia", sort_order: 9},
      %{value: "ohafia", label: "Ohafia", parent_value: "abia", sort_order: 10},
      %{value: "osisioma", label: "Osisioma", parent_value: "abia", sort_order: 11},
      %{value: "ugwunagbo", label: "Ugwunagbo", parent_value: "abia", sort_order: 12},
      %{value: "ukwa-east", label: "Ukwa East", parent_value: "abia", sort_order: 13},
      %{value: "ukwa-west", label: "Ukwa West", parent_value: "abia", sort_order: 14},
      %{value: "umuahia-north", label: "Umuahia North", parent_value: "abia", sort_order: 15},
      %{value: "umuahia-south", label: "Umuahia South", parent_value: "abia", sort_order: 16},
      %{value: "umu-nneochi", label: "Umu Nneochi", parent_value: "abia", sort_order: 17}
    ]
  },
  "lagos" => %{
    name: "Lagos LGAs",
    slug: "ng-lgas-lagos",
    description: "Local Government Areas in Lagos State",
    values: [
      %{value: "agege", label: "Agege", parent_value: "lagos", sort_order: 1},
      %{
        value: "ajeromi-ifelodun",
        label: "Ajeromi-Ifelodun",
        parent_value: "lagos",
        sort_order: 2
      },
      %{value: "alimosho", label: "Alimosho", parent_value: "lagos", sort_order: 3},
      %{value: "amuwo-odofin", label: "Amuwo-Odofin", parent_value: "lagos", sort_order: 4},
      %{value: "apapa", label: "Apapa", parent_value: "lagos", sort_order: 5},
      %{value: "badagry", label: "Badagry", parent_value: "lagos", sort_order: 6},
      %{value: "epe", label: "Epe", parent_value: "lagos", sort_order: 7},
      %{value: "eti-osa", label: "Eti-Osa", parent_value: "lagos", sort_order: 8},
      %{value: "ibeju-lekki", label: "Ibeju-Lekki", parent_value: "lagos", sort_order: 9},
      %{value: "ifako-ijaiye", label: "Ifako-Ijaiye", parent_value: "lagos", sort_order: 10},
      %{value: "ikeja", label: "Ikeja", parent_value: "lagos", sort_order: 11},
      %{value: "ikorodu", label: "Ikorodu", parent_value: "lagos", sort_order: 12},
      %{value: "kosofe", label: "Kosofe", parent_value: "lagos", sort_order: 13},
      %{value: "lagos-island", label: "Lagos Island", parent_value: "lagos", sort_order: 14},
      %{value: "lagos-mainland", label: "Lagos Mainland", parent_value: "lagos", sort_order: 15},
      %{value: "mushin", label: "Mushin", parent_value: "lagos", sort_order: 16},
      %{value: "ojo", label: "Ojo", parent_value: "lagos", sort_order: 17},
      %{value: "oshodi-isolo", label: "Oshodi-Isolo", parent_value: "lagos", sort_order: 18},
      %{value: "shomolu", label: "Shomolu", parent_value: "lagos", sort_order: 19},
      %{value: "surulere", label: "Surulere", parent_value: "lagos", sort_order: 20}
    ]
  },
  "fct" => %{
    name: "FCT LGAs",
    slug: "ng-lgas-fct",
    description: "Area Councils in Federal Capital Territory",
    values: [
      %{value: "abaji", label: "Abaji", parent_value: "fct", sort_order: 1},
      %{value: "abuja-municipal", label: "Abuja Municipal", parent_value: "fct", sort_order: 2},
      %{value: "bwari", label: "Bwari", parent_value: "fct", sort_order: 3},
      %{value: "gwagwalada", label: "Gwagwalada", parent_value: "fct", sort_order: 4},
      %{value: "kuje", label: "Kuje", parent_value: "fct", sort_order: 5},
      %{value: "kwali", label: "Kwali", parent_value: "fct", sort_order: 6}
    ]
  }
}

# Create child option sets for each state's LGAs
for {_state_value, lga_data} <- lgas_by_state do
  case OptionSet
       |> Ash.Query.filter(slug == ^lga_data.slug)
       |> Ash.read_one(authorize?: false) do
    {:ok, nil} ->
      OptionSet
      |> Ash.Changeset.for_create(
        :create_with_values,
        %{
          name: lga_data.name,
          slug: lga_data.slug,
          description: lga_data.description,
          parent_id: states_option_set && states_option_set.id,
          values: lga_data.values
        },
        authorize?: false
      )
      |> Ash.create!()

      lga_count = length(lga_data.values)
      IO.puts("✓ Created child option set: #{lga_data.name} (#{lga_count} LGAs)")

    {:ok, _existing} ->
      IO.puts("⊙ Child option set already exists, skipping: #{lga_data.name}")

    _ ->
      IO.puts("✗ Error checking child option set: #{lga_data.name}")
  end
end

IO.puts("\n✓ Done seeding Nigerian locations (3 states, 43 LGAs)")
IO.puts("  - Abia: 17 LGAs")
IO.puts("  - Lagos: 20 LGAs")
IO.puts("  - FCT: 6 LGAs\n")
