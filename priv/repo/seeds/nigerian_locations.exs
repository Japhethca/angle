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
    %{value: "Abia", label: "Abia", sort_order: 1},
    %{value: "Adamawa", label: "Adamawa", sort_order: 2},
    %{value: "Akwa Ibom", label: "Akwa Ibom", sort_order: 3},
    %{value: "Anambra", label: "Anambra", sort_order: 4},
    %{value: "Bauchi", label: "Bauchi", sort_order: 5},
    %{value: "Bayelsa", label: "Bayelsa", sort_order: 6},
    %{value: "Benue", label: "Benue", sort_order: 7},
    %{value: "Borno", label: "Borno", sort_order: 8},
    %{value: "Cross River", label: "Cross River", sort_order: 9},
    %{value: "Delta", label: "Delta", sort_order: 10},
    %{value: "Ebonyi", label: "Ebonyi", sort_order: 11},
    %{value: "Edo", label: "Edo", sort_order: 12},
    %{value: "Ekiti", label: "Ekiti", sort_order: 13},
    %{value: "Enugu", label: "Enugu", sort_order: 14},
    %{value: "FCT", label: "Federal Capital Territory", sort_order: 15},
    %{value: "Gombe", label: "Gombe", sort_order: 16},
    %{value: "Imo", label: "Imo", sort_order: 17},
    %{value: "Jigawa", label: "Jigawa", sort_order: 18},
    %{value: "Kaduna", label: "Kaduna", sort_order: 19},
    %{value: "Kano", label: "Kano", sort_order: 20},
    %{value: "Katsina", label: "Katsina", sort_order: 21},
    %{value: "Kebbi", label: "Kebbi", sort_order: 22},
    %{value: "Kogi", label: "Kogi", sort_order: 23},
    %{value: "Kwara", label: "Kwara", sort_order: 24},
    %{value: "Lagos", label: "Lagos", sort_order: 25},
    %{value: "Nasarawa", label: "Nasarawa", sort_order: 26},
    %{value: "Niger", label: "Niger", sort_order: 27},
    %{value: "Ogun", label: "Ogun", sort_order: 28},
    %{value: "Ondo", label: "Ondo", sort_order: 29},
    %{value: "Osun", label: "Osun", sort_order: 30},
    %{value: "Oyo", label: "Oyo", sort_order: 31},
    %{value: "Plateau", label: "Plateau", sort_order: 32},
    %{value: "Rivers", label: "Rivers", sort_order: 33},
    %{value: "Sokoto", label: "Sokoto", sort_order: 34},
    %{value: "Taraba", label: "Taraba", sort_order: 35},
    %{value: "Yobe", label: "Yobe", sort_order: 36},
    %{value: "Zamfara", label: "Zamfara", sort_order: 37}
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
      IO.puts("⊙ Parent option set already exists, updating values: #{states_data.name}")

      # Load existing values
      existing = Ash.load!(existing, [:option_set_values], authorize?: false)

      # Get current state values
      current_values = MapSet.new(existing.option_set_values, & &1.value)
      new_values = MapSet.new(states_data.values, & &1.value)

      # Determine which values to add
      to_add = MapSet.difference(new_values, current_values) |> MapSet.to_list()

      if length(to_add) > 0 do
        # Add missing states
        values_to_add =
          Enum.filter(states_data.values, fn v -> v.value in to_add end)

        for value_data <- values_to_add do
          Angle.Catalog.OptionSetValue
          |> Ash.Changeset.for_create(
            :create,
            Map.put(value_data, :option_set_id, existing.id),
            authorize?: false
          )
          |> Ash.create!()
        end

        IO.puts("  Added #{length(to_add)} new states")
      end

      existing

    _ ->
      IO.puts("✗ Error checking parent option set: #{states_data.name}")
      nil
  end

# ── Nigerian LGAs (Child Option Sets) ────────────────────────────────

lgas_by_state = %{
  "Abia" => %{
    name: "Abia LGAs",
    slug: "ng-lgas-abia",
    description: "Local Government Areas in Abia State",
    values: [
      %{value: "aba-north", label: "Aba North", parent_value: "Abia", sort_order: 1},
      %{value: "aba-south", label: "Aba South", parent_value: "Abia", sort_order: 2},
      %{value: "arochukwu", label: "Arochukwu", parent_value: "Abia", sort_order: 3},
      %{value: "bende", label: "Bende", parent_value: "Abia", sort_order: 4},
      %{value: "ikwuano", label: "Ikwuano", parent_value: "Abia", sort_order: 5},
      %{
        value: "isiala-ngwa-north",
        label: "Isiala-Ngwa North",
        parent_value: "Abia",
        sort_order: 6
      },
      %{
        value: "isiala-ngwa-south",
        label: "Isiala-Ngwa South",
        parent_value: "Abia",
        sort_order: 7
      },
      %{value: "isuikwato", label: "Isuikwato", parent_value: "Abia", sort_order: 8},
      %{value: "obi-nwa", label: "Obi Nwa", parent_value: "Abia", sort_order: 9},
      %{value: "ohafia", label: "Ohafia", parent_value: "Abia", sort_order: 10},
      %{value: "osisioma-ngwa", label: "Osisioma Ngwa", parent_value: "Abia", sort_order: 11},
      %{value: "ugwunagbo", label: "Ugwunagbo", parent_value: "Abia", sort_order: 12},
      %{value: "ukwa-east", label: "Ukwa East", parent_value: "Abia", sort_order: 13},
      %{value: "ukwa-west", label: "Ukwa West", parent_value: "Abia", sort_order: 14},
      %{value: "umuahia-north", label: "Umuahia North", parent_value: "Abia", sort_order: 15},
      %{value: "umuahia-south", label: "Umuahia South", parent_value: "Abia", sort_order: 16},
      %{value: "umu-neochi", label: "Umu-Neochi", parent_value: "Abia", sort_order: 17}
    ]
  },
  "Adamawa" => %{
    name: "Adamawa LGAs",
    slug: "ng-lgas-adamawa",
    description: "Local Government Areas in Adamawa State",
    values: [
      %{value: "demsa", label: "Demsa", parent_value: "Adamawa", sort_order: 1},
      %{value: "fufore", label: "Fufore", parent_value: "Adamawa", sort_order: 2},
      %{value: "ganaye", label: "Ganaye", parent_value: "Adamawa", sort_order: 3},
      %{value: "gireri", label: "Gireri", parent_value: "Adamawa", sort_order: 4},
      %{value: "gombi", label: "Gombi", parent_value: "Adamawa", sort_order: 5},
      %{value: "guyuk", label: "Guyuk", parent_value: "Adamawa", sort_order: 6},
      %{value: "hong", label: "Hong", parent_value: "Adamawa", sort_order: 7},
      %{value: "jada", label: "Jada", parent_value: "Adamawa", sort_order: 8},
      %{value: "lamurde", label: "Lamurde", parent_value: "Adamawa", sort_order: 9},
      %{value: "madagali", label: "Madagali", parent_value: "Adamawa", sort_order: 10},
      %{value: "maiha", label: "Maiha", parent_value: "Adamawa", sort_order: 11},
      %{value: "mayo-belwa", label: "Mayo-Belwa", parent_value: "Adamawa", sort_order: 12},
      %{value: "michika", label: "Michika", parent_value: "Adamawa", sort_order: 13},
      %{value: "mubi-north", label: "Mubi North", parent_value: "Adamawa", sort_order: 14},
      %{value: "mubi-south", label: "Mubi South", parent_value: "Adamawa", sort_order: 15},
      %{value: "numan", label: "Numan", parent_value: "Adamawa", sort_order: 16},
      %{value: "shelleng", label: "Shelleng", parent_value: "Adamawa", sort_order: 17},
      %{value: "song", label: "Song", parent_value: "Adamawa", sort_order: 18},
      %{value: "toungo", label: "Toungo", parent_value: "Adamawa", sort_order: 19},
      %{value: "yola-north", label: "Yola North", parent_value: "Adamawa", sort_order: 20},
      %{value: "yola-south", label: "Yola South", parent_value: "Adamawa", sort_order: 21}
    ]
  },
  "Akwa Ibom" => %{
    name: "Akwa Ibom LGAs",
    slug: "ng-lgas-akwa-ibom",
    description: "Local Government Areas in Akwa Ibom State",
    values: [
      %{value: "abak", label: "Abak", parent_value: "Akwa Ibom", sort_order: 1},
      %{value: "eastern-obolo", label: "Eastern Obolo", parent_value: "Akwa Ibom", sort_order: 2},
      %{value: "eket", label: "Eket", parent_value: "Akwa Ibom", sort_order: 3},
      %{value: "esit-eket", label: "Esit Eket", parent_value: "Akwa Ibom", sort_order: 4},
      %{value: "essien-udim", label: "Essien Udim", parent_value: "Akwa Ibom", sort_order: 5},
      %{value: "etim-ekpo", label: "Etim Ekpo", parent_value: "Akwa Ibom", sort_order: 6},
      %{value: "etinan", label: "Etinan", parent_value: "Akwa Ibom", sort_order: 7},
      %{value: "ibeno", label: "Ibeno", parent_value: "Akwa Ibom", sort_order: 8},
      %{
        value: "ibesikpo-asutan",
        label: "Ibesikpo Asutan",
        parent_value: "Akwa Ibom",
        sort_order: 9
      },
      %{value: "ibiono-ibom", label: "Ibiono Ibom", parent_value: "Akwa Ibom", sort_order: 10},
      %{value: "ika", label: "Ika", parent_value: "Akwa Ibom", sort_order: 11},
      %{value: "ikono", label: "Ikono", parent_value: "Akwa Ibom", sort_order: 12},
      %{value: "ikot-abasi", label: "Ikot Abasi", parent_value: "Akwa Ibom", sort_order: 13},
      %{value: "ikot-ekpene", label: "Ikot Ekpene", parent_value: "Akwa Ibom", sort_order: 14},
      %{value: "ini", label: "Ini", parent_value: "Akwa Ibom", sort_order: 15},
      %{value: "itu", label: "Itu", parent_value: "Akwa Ibom", sort_order: 16},
      %{value: "mbo", label: "Mbo", parent_value: "Akwa Ibom", sort_order: 17},
      %{value: "mkpat-enin", label: "Mkpat Enin", parent_value: "Akwa Ibom", sort_order: 18},
      %{value: "nsit-atai", label: "Nsit Atai", parent_value: "Akwa Ibom", sort_order: 19},
      %{value: "nsit-ibom", label: "Nsit Ibom", parent_value: "Akwa Ibom", sort_order: 20},
      %{value: "nsit-ubium", label: "Nsit Ubium", parent_value: "Akwa Ibom", sort_order: 21},
      %{value: "obot-akara", label: "Obot Akara", parent_value: "Akwa Ibom", sort_order: 22},
      %{value: "okobo", label: "Okobo", parent_value: "Akwa Ibom", sort_order: 23},
      %{value: "onna", label: "Onna", parent_value: "Akwa Ibom", sort_order: 24},
      %{value: "oron", label: "Oron", parent_value: "Akwa Ibom", sort_order: 25},
      %{value: "oruk-anam", label: "Oruk Anam", parent_value: "Akwa Ibom", sort_order: 26},
      %{value: "udung-uko", label: "Udung Uko", parent_value: "Akwa Ibom", sort_order: 27},
      %{value: "ukanafun", label: "Ukanafun", parent_value: "Akwa Ibom", sort_order: 28},
      %{value: "uruan", label: "Uruan", parent_value: "Akwa Ibom", sort_order: 29},
      %{
        value: "urue-offong-oruko",
        label: "Urue-Offong/Oruko",
        parent_value: "Akwa Ibom",
        sort_order: 30
      },
      %{value: "uyo", label: "Uyo", parent_value: "Akwa Ibom", sort_order: 31}
    ]
  },
  "Anambra" => %{
    name: "Anambra LGAs",
    slug: "ng-lgas-anambra",
    description: "Local Government Areas in Anambra State",
    values: [
      %{value: "aguata", label: "Aguata", parent_value: "Anambra", sort_order: 1},
      %{value: "anambra-east", label: "Anambra East", parent_value: "Anambra", sort_order: 2},
      %{value: "anambra-west", label: "Anambra West", parent_value: "Anambra", sort_order: 3},
      %{value: "anaocha", label: "Anaocha", parent_value: "Anambra", sort_order: 4},
      %{value: "awka-north", label: "Awka North", parent_value: "Anambra", sort_order: 5},
      %{value: "awka-south", label: "Awka South", parent_value: "Anambra", sort_order: 6},
      %{value: "ayamelum", label: "Ayamelum", parent_value: "Anambra", sort_order: 7},
      %{value: "dunukofia", label: "Dunukofia", parent_value: "Anambra", sort_order: 8},
      %{value: "ekwusigo", label: "Ekwusigo", parent_value: "Anambra", sort_order: 9},
      %{value: "idemili-north", label: "Idemili North", parent_value: "Anambra", sort_order: 10},
      %{value: "idemili-south", label: "Idemili South", parent_value: "Anambra", sort_order: 11},
      %{value: "ihiala", label: "Ihiala", parent_value: "Anambra", sort_order: 12},
      %{value: "njikoka", label: "Njikoka", parent_value: "Anambra", sort_order: 13},
      %{value: "nnewi-north", label: "Nnewi North", parent_value: "Anambra", sort_order: 14},
      %{value: "nnewi-south", label: "Nnewi South", parent_value: "Anambra", sort_order: 15},
      %{value: "ogbaru", label: "Ogbaru", parent_value: "Anambra", sort_order: 16},
      %{value: "onitsha-north", label: "Onitsha North", parent_value: "Anambra", sort_order: 17},
      %{value: "onitsha-south", label: "Onitsha South", parent_value: "Anambra", sort_order: 18},
      %{value: "orumba-north", label: "Orumba North", parent_value: "Anambra", sort_order: 19},
      %{value: "orumba-south", label: "Orumba South", parent_value: "Anambra", sort_order: 20},
      %{value: "oyi", label: "Oyi", parent_value: "Anambra", sort_order: 21}
    ]
  },
  "Bauchi" => %{
    name: "Bauchi LGAs",
    slug: "ng-lgas-bauchi",
    description: "Local Government Areas in Bauchi State",
    values: [
      %{value: "alkaleri", label: "Alkaleri", parent_value: "Bauchi", sort_order: 1},
      %{value: "Bauchi", label: "Bauchi", parent_value: "Bauchi", sort_order: 2},
      %{value: "bogoro", label: "Bogoro", parent_value: "Bauchi", sort_order: 3},
      %{value: "damban", label: "Damban", parent_value: "Bauchi", sort_order: 4},
      %{value: "darazo", label: "Darazo", parent_value: "Bauchi", sort_order: 5},
      %{value: "dass", label: "Dass", parent_value: "Bauchi", sort_order: 6},
      %{value: "ganjuwa", label: "Ganjuwa", parent_value: "Bauchi", sort_order: 7},
      %{value: "giade", label: "Giade", parent_value: "Bauchi", sort_order: 8},
      %{value: "itas-gadau", label: "Itas/Gadau", parent_value: "Bauchi", sort_order: 9},
      %{value: "jamaare", label: "Jama'are", parent_value: "Bauchi", sort_order: 10},
      %{value: "katagum", label: "Katagum", parent_value: "Bauchi", sort_order: 11},
      %{value: "kirfi", label: "Kirfi", parent_value: "Bauchi", sort_order: 12},
      %{value: "misau", label: "Misau", parent_value: "Bauchi", sort_order: 13},
      %{value: "ningi", label: "Ningi", parent_value: "Bauchi", sort_order: 14},
      %{value: "shira", label: "Shira", parent_value: "Bauchi", sort_order: 15},
      %{value: "tafawa-balewa", label: "Tafawa-Balewa", parent_value: "Bauchi", sort_order: 16},
      %{value: "toro", label: "Toro", parent_value: "Bauchi", sort_order: 17},
      %{value: "warji", label: "Warji", parent_value: "Bauchi", sort_order: 18},
      %{value: "zaki", label: "Zaki", parent_value: "Bauchi", sort_order: 19}
    ]
  },
  "Bayelsa" => %{
    name: "Bayelsa LGAs",
    slug: "ng-lgas-bayelsa",
    description: "Local Government Areas in Bayelsa State",
    values: [
      %{value: "brass", label: "Brass", parent_value: "Bayelsa", sort_order: 1},
      %{value: "ekeremor", label: "Ekeremor", parent_value: "Bayelsa", sort_order: 2},
      %{
        value: "kolokuma-opokuma",
        label: "Kolokuma/Opokuma",
        parent_value: "Bayelsa",
        sort_order: 3
      },
      %{value: "nembe", label: "Nembe", parent_value: "Bayelsa", sort_order: 4},
      %{value: "ogbia", label: "Ogbia", parent_value: "Bayelsa", sort_order: 5},
      %{value: "sagbama", label: "Sagbama", parent_value: "Bayelsa", sort_order: 6},
      %{value: "southern-jaw", label: "Southern Jaw", parent_value: "Bayelsa", sort_order: 7},
      %{value: "yenegoa", label: "Yenegoa", parent_value: "Bayelsa", sort_order: 8}
    ]
  },
  "Benue" => %{
    name: "Benue LGAs",
    slug: "ng-lgas-benue",
    description: "Local Government Areas in Benue State",
    values: [
      %{value: "ado", label: "Ado", parent_value: "Benue", sort_order: 1},
      %{value: "agatu", label: "Agatu", parent_value: "Benue", sort_order: 2},
      %{value: "apa", label: "Apa", parent_value: "Benue", sort_order: 3},
      %{value: "buruku", label: "Buruku", parent_value: "Benue", sort_order: 4},
      %{value: "gboko", label: "Gboko", parent_value: "Benue", sort_order: 5},
      %{value: "guma", label: "Guma", parent_value: "Benue", sort_order: 6},
      %{value: "gwer-east", label: "Gwer East", parent_value: "Benue", sort_order: 7},
      %{value: "gwer-west", label: "Gwer West", parent_value: "Benue", sort_order: 8},
      %{value: "katsina-ala", label: "Katsina-Ala", parent_value: "Benue", sort_order: 9},
      %{value: "konshisha", label: "Konshisha", parent_value: "Benue", sort_order: 10},
      %{value: "kwande", label: "Kwande", parent_value: "Benue", sort_order: 11},
      %{value: "logo", label: "Logo", parent_value: "Benue", sort_order: 12},
      %{value: "makurdi", label: "Makurdi", parent_value: "Benue", sort_order: 13},
      %{value: "obi", label: "Obi", parent_value: "Benue", sort_order: 14},
      %{value: "ogbadibo", label: "Ogbadibo", parent_value: "Benue", sort_order: 15},
      %{value: "oju", label: "Oju", parent_value: "Benue", sort_order: 16},
      %{value: "okpokwu", label: "Okpokwu", parent_value: "Benue", sort_order: 17},
      %{value: "ohimini", label: "Ohimini", parent_value: "Benue", sort_order: 18},
      %{value: "oturkpo", label: "Oturkpo", parent_value: "Benue", sort_order: 19},
      %{value: "tarka", label: "Tarka", parent_value: "Benue", sort_order: 20},
      %{value: "ukum", label: "Ukum", parent_value: "Benue", sort_order: 21},
      %{value: "ushongo", label: "Ushongo", parent_value: "Benue", sort_order: 22},
      %{value: "vandeikya", label: "Vandeikya", parent_value: "Benue", sort_order: 23}
    ]
  },
  "Borno" => %{
    name: "Borno LGAs",
    slug: "ng-lgas-borno",
    description: "Local Government Areas in Borno State",
    values: [
      %{value: "abadam", label: "Abadam", parent_value: "Borno", sort_order: 1},
      %{value: "askira-uba", label: "Askira/Uba", parent_value: "Borno", sort_order: 2},
      %{value: "bama", label: "Bama", parent_value: "Borno", sort_order: 3},
      %{value: "bayo", label: "Bayo", parent_value: "Borno", sort_order: 4},
      %{value: "biu", label: "Biu", parent_value: "Borno", sort_order: 5},
      %{value: "chibok", label: "Chibok", parent_value: "Borno", sort_order: 6},
      %{value: "damboa", label: "Damboa", parent_value: "Borno", sort_order: 7},
      %{value: "dikwa", label: "Dikwa", parent_value: "Borno", sort_order: 8},
      %{value: "gubio", label: "Gubio", parent_value: "Borno", sort_order: 9},
      %{value: "guzamala", label: "Guzamala", parent_value: "Borno", sort_order: 10},
      %{value: "gwoza", label: "Gwoza", parent_value: "Borno", sort_order: 11},
      %{value: "hawul", label: "Hawul", parent_value: "Borno", sort_order: 12},
      %{value: "jere", label: "Jere", parent_value: "Borno", sort_order: 13},
      %{value: "kaga", label: "Kaga", parent_value: "Borno", sort_order: 14},
      %{value: "kala-balge", label: "Kala/Balge", parent_value: "Borno", sort_order: 15},
      %{value: "konduga", label: "Konduga", parent_value: "Borno", sort_order: 16},
      %{value: "kukawa", label: "Kukawa", parent_value: "Borno", sort_order: 17},
      %{value: "kwaya-kusar", label: "Kwaya Kusar", parent_value: "Borno", sort_order: 18},
      %{value: "mafa", label: "Mafa", parent_value: "Borno", sort_order: 19},
      %{value: "magumeri", label: "Magumeri", parent_value: "Borno", sort_order: 20},
      %{value: "maiduguri", label: "Maiduguri", parent_value: "Borno", sort_order: 21},
      %{value: "marte", label: "Marte", parent_value: "Borno", sort_order: 22},
      %{value: "mobbar", label: "Mobbar", parent_value: "Borno", sort_order: 23},
      %{value: "monguno", label: "Monguno", parent_value: "Borno", sort_order: 24},
      %{value: "ngala", label: "Ngala", parent_value: "Borno", sort_order: 25},
      %{value: "nganzai", label: "Nganzai", parent_value: "Borno", sort_order: 26},
      %{value: "shani", label: "Shani", parent_value: "Borno", sort_order: 27}
    ]
  },
  "Cross River" => %{
    name: "Cross River LGAs",
    slug: "ng-lgas-cross-river",
    description: "Local Government Areas in Cross River State",
    values: [
      %{value: "akpabuyo", label: "Akpabuyo", parent_value: "Cross River", sort_order: 1},
      %{value: "odukpani", label: "Odukpani", parent_value: "Cross River", sort_order: 2},
      %{value: "akamkpa", label: "Akamkpa", parent_value: "Cross River", sort_order: 3},
      %{value: "biase", label: "Biase", parent_value: "Cross River", sort_order: 4},
      %{value: "abi", label: "Abi", parent_value: "Cross River", sort_order: 5},
      %{value: "ikom", label: "Ikom", parent_value: "Cross River", sort_order: 6},
      %{value: "yarkur", label: "Yarkur", parent_value: "Cross River", sort_order: 7},
      %{value: "odubra", label: "Odubra", parent_value: "Cross River", sort_order: 8},
      %{value: "boki", label: "Boki", parent_value: "Cross River", sort_order: 9},
      %{value: "ogoja", label: "Ogoja", parent_value: "Cross River", sort_order: 10},
      %{value: "yala", label: "Yala", parent_value: "Cross River", sort_order: 11},
      %{value: "obanliku", label: "Obanliku", parent_value: "Cross River", sort_order: 12},
      %{value: "obudu", label: "Obudu", parent_value: "Cross River", sort_order: 13},
      %{
        value: "calabar-south",
        label: "Calabar South",
        parent_value: "Cross River",
        sort_order: 14
      },
      %{value: "etung", label: "Etung", parent_value: "Cross River", sort_order: 15},
      %{value: "bekwara", label: "Bekwara", parent_value: "Cross River", sort_order: 16},
      %{value: "bakassi", label: "Bakassi", parent_value: "Cross River", sort_order: 17},
      %{
        value: "calabar-municipality",
        label: "Calabar Municipality",
        parent_value: "Cross River",
        sort_order: 18
      }
    ]
  },
  "Delta" => %{
    name: "Delta LGAs",
    slug: "ng-lgas-delta",
    description: "Local Government Areas in Delta State",
    values: [
      %{value: "oshimili", label: "Oshimili", parent_value: "Delta", sort_order: 1},
      %{value: "aniocha", label: "Aniocha", parent_value: "Delta", sort_order: 2},
      %{value: "aniocha-south", label: "Aniocha South", parent_value: "Delta", sort_order: 3},
      %{value: "ika-south", label: "Ika South", parent_value: "Delta", sort_order: 4},
      %{value: "ika-north-east", label: "Ika North-East", parent_value: "Delta", sort_order: 5},
      %{value: "ndokwa-west", label: "Ndokwa West", parent_value: "Delta", sort_order: 6},
      %{value: "ndokwa-east", label: "Ndokwa East", parent_value: "Delta", sort_order: 7},
      %{value: "isoko-south", label: "Isoko South", parent_value: "Delta", sort_order: 8},
      %{value: "isoko-north", label: "Isoko North", parent_value: "Delta", sort_order: 9},
      %{value: "bomadi", label: "Bomadi", parent_value: "Delta", sort_order: 10},
      %{value: "burutu", label: "Burutu", parent_value: "Delta", sort_order: 11},
      %{value: "ughelli-south", label: "Ughelli South", parent_value: "Delta", sort_order: 12},
      %{value: "ughelli-north", label: "Ughelli North", parent_value: "Delta", sort_order: 13},
      %{value: "ethiope-west", label: "Ethiope West", parent_value: "Delta", sort_order: 14},
      %{value: "ethiope-east", label: "Ethiope East", parent_value: "Delta", sort_order: 15},
      %{value: "sapele", label: "Sapele", parent_value: "Delta", sort_order: 16},
      %{value: "okpe", label: "Okpe", parent_value: "Delta", sort_order: 17},
      %{value: "warri-north", label: "Warri North", parent_value: "Delta", sort_order: 18},
      %{value: "warri-south", label: "Warri South", parent_value: "Delta", sort_order: 19},
      %{value: "uvwie", label: "Uvwie", parent_value: "Delta", sort_order: 20},
      %{value: "udu", label: "Udu", parent_value: "Delta", sort_order: 21},
      %{value: "warri-central", label: "Warri Central", parent_value: "Delta", sort_order: 22},
      %{value: "ukwani", label: "Ukwani", parent_value: "Delta", sort_order: 23},
      %{value: "oshimili-north", label: "Oshimili North", parent_value: "Delta", sort_order: 24},
      %{value: "patani", label: "Patani", parent_value: "Delta", sort_order: 25}
    ]
  },
  "Ebonyi" => %{
    name: "Ebonyi LGAs",
    slug: "ng-lgas-ebonyi",
    description: "Local Government Areas in Ebonyi State",
    values: [
      %{value: "edda", label: "Edda", parent_value: "Ebonyi", sort_order: 1},
      %{value: "afikpo", label: "Afikpo", parent_value: "Ebonyi", sort_order: 2},
      %{value: "onicha", label: "Onicha", parent_value: "Ebonyi", sort_order: 3},
      %{value: "ohaozara", label: "Ohaozara", parent_value: "Ebonyi", sort_order: 4},
      %{value: "abakaliki", label: "Abakaliki", parent_value: "Ebonyi", sort_order: 5},
      %{value: "ishielu", label: "Ishielu", parent_value: "Ebonyi", sort_order: 6},
      %{value: "ikwo", label: "Ikwo", parent_value: "Ebonyi", sort_order: 7},
      %{value: "ezza", label: "Ezza", parent_value: "Ebonyi", sort_order: 8},
      %{value: "ezza-south", label: "Ezza South", parent_value: "Ebonyi", sort_order: 9},
      %{value: "ohaukwu", label: "Ohaukwu", parent_value: "Ebonyi", sort_order: 10},
      %{value: "Ebonyi", label: "Ebonyi", parent_value: "Ebonyi", sort_order: 11},
      %{value: "ivo", label: "Ivo", parent_value: "Ebonyi", sort_order: 12}
    ]
  },
  "Edo" => %{
    name: "Edo LGAs",
    slug: "ng-lgas-edo",
    description: "Local Government Areas in Edo State",
    values: [
      %{value: "esan-north-east", label: "Esan North-East", parent_value: "Edo", sort_order: 1},
      %{value: "esan-central", label: "Esan Central", parent_value: "Edo", sort_order: 2},
      %{value: "esan-west", label: "Esan West", parent_value: "Edo", sort_order: 3},
      %{value: "egor", label: "Egor", parent_value: "Edo", sort_order: 4},
      %{value: "ukpoba", label: "Ukpoba", parent_value: "Edo", sort_order: 5},
      %{value: "central", label: "Central", parent_value: "Edo", sort_order: 6},
      %{value: "etsako-central", label: "Etsako Central", parent_value: "Edo", sort_order: 7},
      %{value: "igueben", label: "Igueben", parent_value: "Edo", sort_order: 8},
      %{value: "oredo", label: "Oredo", parent_value: "Edo", sort_order: 9},
      %{value: "ovia-southwest", label: "Ovia Southwest", parent_value: "Edo", sort_order: 10},
      %{value: "ovia-southeast", label: "Ovia Southeast", parent_value: "Edo", sort_order: 11},
      %{value: "orhionwon", label: "Orhionwon", parent_value: "Edo", sort_order: 12},
      %{value: "uhunmwonde", label: "Uhunmwonde", parent_value: "Edo", sort_order: 13},
      %{value: "etsako-east", label: "Etsako East", parent_value: "Edo", sort_order: 14},
      %{value: "esan-south-east", label: "Esan South-East", parent_value: "Edo", sort_order: 15}
    ]
  },
  "Ekiti" => %{
    name: "Ekiti LGAs",
    slug: "ng-lgas-ekiti",
    description: "Local Government Areas in Ekiti State",
    values: [
      %{value: "ado", label: "Ado", parent_value: "Ekiti", sort_order: 1},
      %{value: "ekiti-east", label: "Ekiti-East", parent_value: "Ekiti", sort_order: 2},
      %{value: "ekiti-west", label: "Ekiti-West", parent_value: "Ekiti", sort_order: 3},
      %{value: "emure-ise-orun", label: "Emure/Ise/Orun", parent_value: "Ekiti", sort_order: 4},
      %{
        value: "ekiti-south-west",
        label: "Ekiti South-West",
        parent_value: "Ekiti",
        sort_order: 5
      },
      %{value: "ikere", label: "Ikere", parent_value: "Ekiti", sort_order: 6},
      %{value: "irepodun", label: "Irepodun", parent_value: "Ekiti", sort_order: 7},
      %{value: "ijero", label: "Ijero", parent_value: "Ekiti", sort_order: 8},
      %{value: "ido-osi", label: "Ido/Osi", parent_value: "Ekiti", sort_order: 9},
      %{value: "oye", label: "Oye", parent_value: "Ekiti", sort_order: 10},
      %{value: "ikole", label: "Ikole", parent_value: "Ekiti", sort_order: 11},
      %{value: "moba", label: "Moba", parent_value: "Ekiti", sort_order: 12},
      %{value: "gbonyin", label: "Gbonyin", parent_value: "Ekiti", sort_order: 13},
      %{value: "efon", label: "Efon", parent_value: "Ekiti", sort_order: 14},
      %{value: "ise-orun", label: "Ise/Orun", parent_value: "Ekiti", sort_order: 15},
      %{value: "ilejemeje", label: "Ilejemeje", parent_value: "Ekiti", sort_order: 16}
    ]
  },
  "Enugu" => %{
    name: "Enugu LGAs",
    slug: "ng-lgas-enugu",
    description: "Local Government Areas in Enugu State",
    values: [
      %{value: "enugu-south", label: "Enugu South", parent_value: "Enugu", sort_order: 1},
      %{value: "igbo-eze-south", label: "Igbo-Eze South", parent_value: "Enugu", sort_order: 2},
      %{value: "enugu-north", label: "Enugu North", parent_value: "Enugu", sort_order: 3},
      %{value: "nkanu", label: "Nkanu", parent_value: "Enugu", sort_order: 4},
      %{value: "udi-agwu", label: "Udi Agwu", parent_value: "Enugu", sort_order: 5},
      %{value: "oji-river", label: "Oji-River", parent_value: "Enugu", sort_order: 6},
      %{value: "ezeagu", label: "Ezeagu", parent_value: "Enugu", sort_order: 7},
      %{value: "igbo-eze-north", label: "Igbo-Eze North", parent_value: "Enugu", sort_order: 8},
      %{value: "isi-uzo", label: "Isi-Uzo", parent_value: "Enugu", sort_order: 9},
      %{value: "nsukka", label: "Nsukka", parent_value: "Enugu", sort_order: 10},
      %{value: "igbo-ekiti", label: "Igbo-Ekiti", parent_value: "Enugu", sort_order: 11},
      %{value: "uzo-uwani", label: "Uzo-Uwani", parent_value: "Enugu", sort_order: 12},
      %{value: "enugu-east", label: "Enugu East", parent_value: "Enugu", sort_order: 13},
      %{value: "aninri", label: "Aninri", parent_value: "Enugu", sort_order: 14},
      %{value: "nkanu-east", label: "Nkanu East", parent_value: "Enugu", sort_order: 15},
      %{value: "udenu", label: "Udenu", parent_value: "Enugu", sort_order: 16}
    ]
  },
  "FCT" => %{
    name: "FCT Area Councils",
    slug: "ng-lgas-fct",
    description: "Area Councils in Federal Capital Territory",
    values: [
      %{value: "abaji", label: "Abaji", parent_value: "FCT", sort_order: 1},
      %{value: "abuja-municipal", label: "Abuja Municipal", parent_value: "FCT", sort_order: 2},
      %{value: "bwari", label: "Bwari", parent_value: "FCT", sort_order: 3},
      %{value: "gwagwalada", label: "Gwagwalada", parent_value: "FCT", sort_order: 4},
      %{value: "kuje", label: "Kuje", parent_value: "FCT", sort_order: 5},
      %{value: "kwali", label: "Kwali", parent_value: "FCT", sort_order: 6}
    ]
  },
  "Gombe" => %{
    name: "Gombe LGAs",
    slug: "ng-lgas-gombe",
    description: "Local Government Areas in Gombe State",
    values: [
      %{value: "akko", label: "Akko", parent_value: "Gombe", sort_order: 1},
      %{value: "balanga", label: "Balanga", parent_value: "Gombe", sort_order: 2},
      %{value: "billiri", label: "Billiri", parent_value: "Gombe", sort_order: 3},
      %{value: "dukku", label: "Dukku", parent_value: "Gombe", sort_order: 4},
      %{value: "kaltungo", label: "Kaltungo", parent_value: "Gombe", sort_order: 5},
      %{value: "kwami", label: "Kwami", parent_value: "Gombe", sort_order: 6},
      %{value: "shomgom", label: "Shomgom", parent_value: "Gombe", sort_order: 7},
      %{value: "funakaye", label: "Funakaye", parent_value: "Gombe", sort_order: 8},
      %{value: "Gombe", label: "Gombe", parent_value: "Gombe", sort_order: 9},
      %{value: "nafada-bajoga", label: "Nafada/Bajoga", parent_value: "Gombe", sort_order: 10},
      %{value: "yamaltu-delta", label: "Yamaltu/Delta", parent_value: "Gombe", sort_order: 11}
    ]
  },
  "Imo" => %{
    name: "Imo LGAs",
    slug: "ng-lgas-imo",
    description: "Local Government Areas in Imo State",
    values: [
      %{value: "aboh-mbaise", label: "Aboh-Mbaise", parent_value: "Imo", sort_order: 1},
      %{value: "ahiazu-mbaise", label: "Ahiazu-Mbaise", parent_value: "Imo", sort_order: 2},
      %{value: "ehime-mbano", label: "Ehime-Mbano", parent_value: "Imo", sort_order: 3},
      %{value: "ezinihitte", label: "Ezinihitte", parent_value: "Imo", sort_order: 4},
      %{value: "ideato-north", label: "Ideato North", parent_value: "Imo", sort_order: 5},
      %{value: "ideato-south", label: "Ideato South", parent_value: "Imo", sort_order: 6},
      %{value: "ihitte-uboma", label: "Ihitte/Uboma", parent_value: "Imo", sort_order: 7},
      %{value: "ikeduru", label: "Ikeduru", parent_value: "Imo", sort_order: 8},
      %{value: "isiala-mbano", label: "Isiala Mbano", parent_value: "Imo", sort_order: 9},
      %{value: "isu", label: "Isu", parent_value: "Imo", sort_order: 10},
      %{value: "mbaitoli", label: "Mbaitoli", parent_value: "Imo", sort_order: 11},
      %{value: "ngor-okpala", label: "Ngor-Okpala", parent_value: "Imo", sort_order: 12},
      %{value: "njaba", label: "Njaba", parent_value: "Imo", sort_order: 13},
      %{value: "nwangele", label: "Nwangele", parent_value: "Imo", sort_order: 14},
      %{value: "nkwerre", label: "Nkwerre", parent_value: "Imo", sort_order: 15},
      %{value: "obowo", label: "Obowo", parent_value: "Imo", sort_order: 16},
      %{value: "oguta", label: "Oguta", parent_value: "Imo", sort_order: 17},
      %{value: "ohaji-egbema", label: "Ohaji/Egbema", parent_value: "Imo", sort_order: 18},
      %{value: "okigwe", label: "Okigwe", parent_value: "Imo", sort_order: 19},
      %{value: "orlu", label: "Orlu", parent_value: "Imo", sort_order: 20},
      %{value: "orsu", label: "Orsu", parent_value: "Imo", sort_order: 21},
      %{value: "oru-east", label: "Oru East", parent_value: "Imo", sort_order: 22},
      %{value: "oru-west", label: "Oru West", parent_value: "Imo", sort_order: 23},
      %{
        value: "owerri-municipal",
        label: "Owerri-Municipal",
        parent_value: "Imo",
        sort_order: 24
      },
      %{value: "owerri-north", label: "Owerri North", parent_value: "Imo", sort_order: 25},
      %{value: "owerri-west", label: "Owerri West", parent_value: "Imo", sort_order: 26}
    ]
  },
  "Jigawa" => %{
    name: "Jigawa LGAs",
    slug: "ng-lgas-jigawa",
    description: "Local Government Areas in Jigawa State",
    values: [
      %{value: "auyo", label: "Auyo", parent_value: "Jigawa", sort_order: 1},
      %{value: "babura", label: "Babura", parent_value: "Jigawa", sort_order: 2},
      %{value: "birni-kudu", label: "Birni Kudu", parent_value: "Jigawa", sort_order: 3},
      %{value: "biriniwa", label: "Biriniwa", parent_value: "Jigawa", sort_order: 4},
      %{value: "buji", label: "Buji", parent_value: "Jigawa", sort_order: 5},
      %{value: "dutse", label: "Dutse", parent_value: "Jigawa", sort_order: 6},
      %{value: "gagarawa", label: "Gagarawa", parent_value: "Jigawa", sort_order: 7},
      %{value: "garki", label: "Garki", parent_value: "Jigawa", sort_order: 8},
      %{value: "gumel", label: "Gumel", parent_value: "Jigawa", sort_order: 9},
      %{value: "guri", label: "Guri", parent_value: "Jigawa", sort_order: 10},
      %{value: "gwaram", label: "Gwaram", parent_value: "Jigawa", sort_order: 11},
      %{value: "gwiwa", label: "Gwiwa", parent_value: "Jigawa", sort_order: 12},
      %{value: "hadejia", label: "Hadejia", parent_value: "Jigawa", sort_order: 13},
      %{value: "jahun", label: "Jahun", parent_value: "Jigawa", sort_order: 14},
      %{value: "kafin-hausa", label: "Kafin Hausa", parent_value: "Jigawa", sort_order: 15},
      %{value: "kaugama", label: "Kaugama", parent_value: "Jigawa", sort_order: 16},
      %{value: "kazaure", label: "Kazaure", parent_value: "Jigawa", sort_order: 17},
      %{value: "kiri-kasamma", label: "Kiri Kasamma", parent_value: "Jigawa", sort_order: 18},
      %{value: "kiyawa", label: "Kiyawa", parent_value: "Jigawa", sort_order: 19},
      %{value: "maigatari", label: "Maigatari", parent_value: "Jigawa", sort_order: 20},
      %{value: "malam-madori", label: "Malam Madori", parent_value: "Jigawa", sort_order: 21},
      %{value: "miga", label: "Miga", parent_value: "Jigawa", sort_order: 22},
      %{value: "ringim", label: "Ringim", parent_value: "Jigawa", sort_order: 23},
      %{value: "roni", label: "Roni", parent_value: "Jigawa", sort_order: 24},
      %{value: "sule-tankarkar", label: "Sule-Tankarkar", parent_value: "Jigawa", sort_order: 25},
      %{value: "taura", label: "Taura", parent_value: "Jigawa", sort_order: 26},
      %{value: "yankwashi", label: "Yankwashi", parent_value: "Jigawa", sort_order: 27}
    ]
  },
  "Kaduna" => %{
    name: "Kaduna LGAs",
    slug: "ng-lgas-kaduna",
    description: "Local Government Areas in Kaduna State",
    values: [
      %{value: "birni-gwari", label: "Birni-Gwari", parent_value: "Kaduna", sort_order: 1},
      %{value: "chikun", label: "Chikun", parent_value: "Kaduna", sort_order: 2},
      %{value: "giwa", label: "Giwa", parent_value: "Kaduna", sort_order: 3},
      %{value: "igabi", label: "Igabi", parent_value: "Kaduna", sort_order: 4},
      %{value: "ikara", label: "Ikara", parent_value: "Kaduna", sort_order: 5},
      %{value: "jaba", label: "Jaba", parent_value: "Kaduna", sort_order: 6},
      %{value: "jemaa", label: "Jema'a", parent_value: "Kaduna", sort_order: 7},
      %{value: "kachia", label: "Kachia", parent_value: "Kaduna", sort_order: 8},
      %{value: "kaduna-north", label: "Kaduna North", parent_value: "Kaduna", sort_order: 9},
      %{value: "kaduna-south", label: "Kaduna South", parent_value: "Kaduna", sort_order: 10},
      %{value: "kagarko", label: "Kagarko", parent_value: "Kaduna", sort_order: 11},
      %{value: "kajuru", label: "Kajuru", parent_value: "Kaduna", sort_order: 12},
      %{value: "kaura", label: "Kaura", parent_value: "Kaduna", sort_order: 13},
      %{value: "kauru", label: "Kauru", parent_value: "Kaduna", sort_order: 14},
      %{value: "kubau", label: "Kubau", parent_value: "Kaduna", sort_order: 15},
      %{value: "kudan", label: "Kudan", parent_value: "Kaduna", sort_order: 16},
      %{value: "lere", label: "Lere", parent_value: "Kaduna", sort_order: 17},
      %{value: "makarfi", label: "Makarfi", parent_value: "Kaduna", sort_order: 18},
      %{value: "sabon-gari", label: "Sabon-Gari", parent_value: "Kaduna", sort_order: 19},
      %{value: "sanga", label: "Sanga", parent_value: "Kaduna", sort_order: 20},
      %{value: "soba", label: "Soba", parent_value: "Kaduna", sort_order: 21},
      %{value: "zango-kataf", label: "Zango-Kataf", parent_value: "Kaduna", sort_order: 22},
      %{value: "zaria", label: "Zaria", parent_value: "Kaduna", sort_order: 23}
    ]
  },
  "Kano" => %{
    name: "Kano LGAs",
    slug: "ng-lgas-kano",
    description: "Local Government Areas in Kano State",
    values: [
      %{value: "ajingi", label: "Ajingi", parent_value: "Kano", sort_order: 1},
      %{value: "albasu", label: "Albasu", parent_value: "Kano", sort_order: 2},
      %{value: "bagwai", label: "Bagwai", parent_value: "Kano", sort_order: 3},
      %{value: "bebeji", label: "Bebeji", parent_value: "Kano", sort_order: 4},
      %{value: "bichi", label: "Bichi", parent_value: "Kano", sort_order: 5},
      %{value: "bunkure", label: "Bunkure", parent_value: "Kano", sort_order: 6},
      %{value: "dala", label: "Dala", parent_value: "Kano", sort_order: 7},
      %{value: "dambatta", label: "Dambatta", parent_value: "Kano", sort_order: 8},
      %{value: "dawakin-kudu", label: "Dawakin Kudu", parent_value: "Kano", sort_order: 9},
      %{value: "dawakin-tofa", label: "Dawakin Tofa", parent_value: "Kano", sort_order: 10},
      %{value: "doguwa", label: "Doguwa", parent_value: "Kano", sort_order: 11},
      %{value: "fagge", label: "Fagge", parent_value: "Kano", sort_order: 12},
      %{value: "gabasawa", label: "Gabasawa", parent_value: "Kano", sort_order: 13},
      %{value: "garko", label: "Garko", parent_value: "Kano", sort_order: 14},
      %{value: "garum-mallam", label: "Garum Mallam", parent_value: "Kano", sort_order: 15},
      %{value: "gaya", label: "Gaya", parent_value: "Kano", sort_order: 16},
      %{value: "gezawa", label: "Gezawa", parent_value: "Kano", sort_order: 17},
      %{value: "gwale", label: "Gwale", parent_value: "Kano", sort_order: 18},
      %{value: "gwarzo", label: "Gwarzo", parent_value: "Kano", sort_order: 19},
      %{value: "kabo", label: "Kabo", parent_value: "Kano", sort_order: 20},
      %{value: "kano-municipal", label: "Kano Municipal", parent_value: "Kano", sort_order: 21},
      %{value: "karaye", label: "Karaye", parent_value: "Kano", sort_order: 22},
      %{value: "kibiya", label: "Kibiya", parent_value: "Kano", sort_order: 23},
      %{value: "kiru", label: "Kiru", parent_value: "Kano", sort_order: 24},
      %{value: "kumbotso", label: "Kumbotso", parent_value: "Kano", sort_order: 25},
      %{value: "ghari", label: "Ghari", parent_value: "Kano", sort_order: 26},
      %{value: "kura", label: "Kura", parent_value: "Kano", sort_order: 27},
      %{value: "madobi", label: "Madobi", parent_value: "Kano", sort_order: 28},
      %{value: "makoda", label: "Makoda", parent_value: "Kano", sort_order: 29},
      %{value: "minjibir", label: "Minjibir", parent_value: "Kano", sort_order: 30},
      %{value: "Nasarawa", label: "Nasarawa", parent_value: "Kano", sort_order: 31},
      %{value: "rano", label: "Rano", parent_value: "Kano", sort_order: 32},
      %{value: "rimin-gado", label: "Rimin Gado", parent_value: "Kano", sort_order: 33},
      %{value: "rogo", label: "Rogo", parent_value: "Kano", sort_order: 34},
      %{value: "shanono", label: "Shanono", parent_value: "Kano", sort_order: 35},
      %{value: "sumaila", label: "Sumaila", parent_value: "Kano", sort_order: 36},
      %{value: "takali", label: "Takali", parent_value: "Kano", sort_order: 37},
      %{value: "tarauni", label: "Tarauni", parent_value: "Kano", sort_order: 38},
      %{value: "tofa", label: "Tofa", parent_value: "Kano", sort_order: 39},
      %{value: "tsanyawa", label: "Tsanyawa", parent_value: "Kano", sort_order: 40},
      %{value: "tudun-wada", label: "Tudun Wada", parent_value: "Kano", sort_order: 41},
      %{value: "ungogo", label: "Ungogo", parent_value: "Kano", sort_order: 42},
      %{value: "warawa", label: "Warawa", parent_value: "Kano", sort_order: 43},
      %{value: "wudil", label: "Wudil", parent_value: "Kano", sort_order: 44}
    ]
  },
  "Katsina" => %{
    name: "Katsina LGAs",
    slug: "ng-lgas-katsina",
    description: "Local Government Areas in Katsina State",
    values: [
      %{value: "bakori", label: "Bakori", parent_value: "Katsina", sort_order: 1},
      %{value: "batagarawa", label: "Batagarawa", parent_value: "Katsina", sort_order: 2},
      %{value: "batsari", label: "Batsari", parent_value: "Katsina", sort_order: 3},
      %{value: "baure", label: "Baure", parent_value: "Katsina", sort_order: 4},
      %{value: "bindawa", label: "Bindawa", parent_value: "Katsina", sort_order: 5},
      %{value: "charanchi", label: "Charanchi", parent_value: "Katsina", sort_order: 6},
      %{value: "dandume", label: "Dandume", parent_value: "Katsina", sort_order: 7},
      %{value: "danja", label: "Danja", parent_value: "Katsina", sort_order: 8},
      %{value: "dan-musa", label: "Dan Musa", parent_value: "Katsina", sort_order: 9},
      %{value: "daura", label: "Daura", parent_value: "Katsina", sort_order: 10},
      %{value: "dutsi", label: "Dutsi", parent_value: "Katsina", sort_order: 11},
      %{value: "dutsin-ma", label: "Dutsin-Ma", parent_value: "Katsina", sort_order: 12},
      %{value: "faskari", label: "Faskari", parent_value: "Katsina", sort_order: 13},
      %{value: "funtua", label: "Funtua", parent_value: "Katsina", sort_order: 14},
      %{value: "ingawa", label: "Ingawa", parent_value: "Katsina", sort_order: 15},
      %{value: "jibia", label: "Jibia", parent_value: "Katsina", sort_order: 16},
      %{value: "kafur", label: "Kafur", parent_value: "Katsina", sort_order: 17},
      %{value: "kaita", label: "Kaita", parent_value: "Katsina", sort_order: 18},
      %{value: "kankara", label: "Kankara", parent_value: "Katsina", sort_order: 19},
      %{value: "kankia", label: "Kankia", parent_value: "Katsina", sort_order: 20},
      %{value: "Katsina", label: "Katsina", parent_value: "Katsina", sort_order: 21},
      %{value: "kurfi", label: "Kurfi", parent_value: "Katsina", sort_order: 22},
      %{value: "kusada", label: "Kusada", parent_value: "Katsina", sort_order: 23},
      %{value: "mai-adua", label: "Mai'Adua", parent_value: "Katsina", sort_order: 24},
      %{value: "malumfashi", label: "Malumfashi", parent_value: "Katsina", sort_order: 25},
      %{value: "mani", label: "Mani", parent_value: "Katsina", sort_order: 26},
      %{value: "mashi", label: "Mashi", parent_value: "Katsina", sort_order: 27},
      %{value: "matazuu", label: "Matazuu", parent_value: "Katsina", sort_order: 28},
      %{value: "musawa", label: "Musawa", parent_value: "Katsina", sort_order: 29},
      %{value: "rimi", label: "Rimi", parent_value: "Katsina", sort_order: 30},
      %{value: "sabuwa", label: "Sabuwa", parent_value: "Katsina", sort_order: 31},
      %{value: "safana", label: "Safana", parent_value: "Katsina", sort_order: 32},
      %{value: "sandamu", label: "Sandamu", parent_value: "Katsina", sort_order: 33},
      %{value: "zango", label: "Zango", parent_value: "Katsina", sort_order: 34}
    ]
  },
  "Kebbi" => %{
    name: "Kebbi LGAs",
    slug: "ng-lgas-kebbi",
    description: "Local Government Areas in Kebbi State",
    values: [
      %{value: "aleiro", label: "Aleiro", parent_value: "Kebbi", sort_order: 1},
      %{value: "arewa-dandi", label: "Arewa-Dandi", parent_value: "Kebbi", sort_order: 2},
      %{value: "argungu", label: "Argungu", parent_value: "Kebbi", sort_order: 3},
      %{value: "augie", label: "Augie", parent_value: "Kebbi", sort_order: 4},
      %{value: "bagudo", label: "Bagudo", parent_value: "Kebbi", sort_order: 5},
      %{value: "birnin-kebbi", label: "Birnin Kebbi", parent_value: "Kebbi", sort_order: 6},
      %{value: "bunza", label: "Bunza", parent_value: "Kebbi", sort_order: 7},
      %{value: "dandi", label: "Dandi", parent_value: "Kebbi", sort_order: 8},
      %{value: "fakai", label: "Fakai", parent_value: "Kebbi", sort_order: 9},
      %{value: "gwandu", label: "Gwandu", parent_value: "Kebbi", sort_order: 10},
      %{value: "jega", label: "Jega", parent_value: "Kebbi", sort_order: 11},
      %{value: "kalgo", label: "Kalgo", parent_value: "Kebbi", sort_order: 12},
      %{value: "koko-besse", label: "Koko/Besse", parent_value: "Kebbi", sort_order: 13},
      %{value: "maiyama", label: "Maiyama", parent_value: "Kebbi", sort_order: 14},
      %{value: "ngaski", label: "Ngaski", parent_value: "Kebbi", sort_order: 15},
      %{value: "sakaba", label: "Sakaba", parent_value: "Kebbi", sort_order: 16},
      %{value: "shanga", label: "Shanga", parent_value: "Kebbi", sort_order: 17},
      %{value: "suru", label: "Suru", parent_value: "Kebbi", sort_order: 18},
      %{value: "wasagu-danko", label: "Wasagu/Danko", parent_value: "Kebbi", sort_order: 19},
      %{value: "yauri", label: "Yauri", parent_value: "Kebbi", sort_order: 20},
      %{value: "zuru", label: "Zuru", parent_value: "Kebbi", sort_order: 21}
    ]
  },
  "Kogi" => %{
    name: "Kogi LGAs",
    slug: "ng-lgas-kogi",
    description: "Local Government Areas in Kogi State",
    values: [
      %{value: "adavi", label: "Adavi", parent_value: "Kogi", sort_order: 1},
      %{value: "ajaokuta", label: "Ajaokuta", parent_value: "Kogi", sort_order: 2},
      %{value: "ankpa", label: "Ankpa", parent_value: "Kogi", sort_order: 3},
      %{value: "bassa", label: "Bassa", parent_value: "Kogi", sort_order: 4},
      %{value: "dekina", label: "Dekina", parent_value: "Kogi", sort_order: 5},
      %{value: "ibaji", label: "Ibaji", parent_value: "Kogi", sort_order: 6},
      %{value: "idah", label: "Idah", parent_value: "Kogi", sort_order: 7},
      %{value: "igalamela-odolu", label: "Igalamela-Odolu", parent_value: "Kogi", sort_order: 8},
      %{value: "ijumu", label: "Ijumu", parent_value: "Kogi", sort_order: 9},
      %{value: "kabba-bunu", label: "Kabba/Bunu", parent_value: "Kogi", sort_order: 10},
      %{value: "Kogi", label: "Kogi", parent_value: "Kogi", sort_order: 11},
      %{value: "lokoja", label: "Lokoja", parent_value: "Kogi", sort_order: 12},
      %{value: "mopa-muro", label: "Mopa-Muro", parent_value: "Kogi", sort_order: 13},
      %{value: "ofu", label: "Ofu", parent_value: "Kogi", sort_order: 14},
      %{value: "ogori-mangongo", label: "Ogori/Mangongo", parent_value: "Kogi", sort_order: 15},
      %{value: "okehi", label: "Okehi", parent_value: "Kogi", sort_order: 16},
      %{value: "okene", label: "Okene", parent_value: "Kogi", sort_order: 17},
      %{value: "olamabolo", label: "Olamabolo", parent_value: "Kogi", sort_order: 18},
      %{value: "omala", label: "Omala", parent_value: "Kogi", sort_order: 19},
      %{value: "yagba-east", label: "Yagba East", parent_value: "Kogi", sort_order: 20},
      %{value: "yagba-west", label: "Yagba West", parent_value: "Kogi", sort_order: 21}
    ]
  },
  "Kwara" => %{
    name: "Kwara LGAs",
    slug: "ng-lgas-kwara",
    description: "Local Government Areas in Kwara State",
    values: [
      %{value: "asa", label: "Asa", parent_value: "Kwara", sort_order: 1},
      %{value: "baruten", label: "Baruten", parent_value: "Kwara", sort_order: 2},
      %{value: "edu", label: "Edu", parent_value: "Kwara", sort_order: 3},
      %{value: "Ekiti", label: "Ekiti", parent_value: "Kwara", sort_order: 4},
      %{value: "ifelodun", label: "Ifelodun", parent_value: "Kwara", sort_order: 5},
      %{value: "ilorin-east", label: "Ilorin East", parent_value: "Kwara", sort_order: 6},
      %{value: "ilorin-west", label: "Ilorin West", parent_value: "Kwara", sort_order: 7},
      %{value: "irepodun", label: "Irepodun", parent_value: "Kwara", sort_order: 8},
      %{value: "isin", label: "Isin", parent_value: "Kwara", sort_order: 9},
      %{value: "kaiama", label: "Kaiama", parent_value: "Kwara", sort_order: 10},
      %{value: "moro", label: "Moro", parent_value: "Kwara", sort_order: 11},
      %{value: "offa", label: "Offa", parent_value: "Kwara", sort_order: 12},
      %{value: "oke-ero", label: "Oke-Ero", parent_value: "Kwara", sort_order: 13},
      %{value: "oyun", label: "Oyun", parent_value: "Kwara", sort_order: 14},
      %{value: "pategi", label: "Pategi", parent_value: "Kwara", sort_order: 15}
    ]
  },
  "Lagos" => %{
    name: "Lagos LGAs",
    slug: "ng-lgas-lagos",
    description: "Local Government Areas in Lagos State",
    values: [
      %{value: "agege", label: "Agege", parent_value: "Lagos", sort_order: 1},
      %{
        value: "ajeromi-ifelodun",
        label: "Ajeromi-Ifelodun",
        parent_value: "Lagos",
        sort_order: 2
      },
      %{value: "alimosho", label: "Alimosho", parent_value: "Lagos", sort_order: 3},
      %{value: "amuwo-odofin", label: "Amuwo-Odofin", parent_value: "Lagos", sort_order: 4},
      %{value: "apapa", label: "Apapa", parent_value: "Lagos", sort_order: 5},
      %{value: "badagry", label: "Badagry", parent_value: "Lagos", sort_order: 6},
      %{value: "epe", label: "Epe", parent_value: "Lagos", sort_order: 7},
      %{value: "eti-osa", label: "Eti-Osa", parent_value: "Lagos", sort_order: 8},
      %{value: "ibeju-lekki", label: "Ibeju/Lekki", parent_value: "Lagos", sort_order: 9},
      %{value: "ifako-ijaye", label: "Ifako-Ijaye", parent_value: "Lagos", sort_order: 10},
      %{value: "ikeja", label: "Ikeja", parent_value: "Lagos", sort_order: 11},
      %{value: "ikorodu", label: "Ikorodu", parent_value: "Lagos", sort_order: 12},
      %{value: "kosofe", label: "Kosofe", parent_value: "Lagos", sort_order: 13},
      %{value: "lagos-island", label: "Lagos Island", parent_value: "Lagos", sort_order: 14},
      %{value: "lagos-mainland", label: "Lagos Mainland", parent_value: "Lagos", sort_order: 15},
      %{value: "mushin", label: "Mushin", parent_value: "Lagos", sort_order: 16},
      %{value: "ojo", label: "Ojo", parent_value: "Lagos", sort_order: 17},
      %{value: "oshodi-isolo", label: "Oshodi-Isolo", parent_value: "Lagos", sort_order: 18},
      %{value: "shomolu", label: "Shomolu", parent_value: "Lagos", sort_order: 19},
      %{value: "surulere", label: "Surulere", parent_value: "Lagos", sort_order: 20}
    ]
  },
  "Nasarawa" => %{
    name: "Nasarawa LGAs",
    slug: "ng-lgas-nasarawa",
    description: "Local Government Areas in Nasarawa State",
    values: [
      %{value: "akwanga", label: "Akwanga", parent_value: "Nasarawa", sort_order: 1},
      %{value: "awe", label: "Awe", parent_value: "Nasarawa", sort_order: 2},
      %{value: "doma", label: "Doma", parent_value: "Nasarawa", sort_order: 3},
      %{value: "karu", label: "Karu", parent_value: "Nasarawa", sort_order: 4},
      %{value: "keana", label: "Keana", parent_value: "Nasarawa", sort_order: 5},
      %{value: "keffi", label: "Keffi", parent_value: "Nasarawa", sort_order: 6},
      %{value: "kokona", label: "Kokona", parent_value: "Nasarawa", sort_order: 7},
      %{value: "lafia", label: "Lafia", parent_value: "Nasarawa", sort_order: 8},
      %{value: "Nasarawa", label: "Nasarawa", parent_value: "Nasarawa", sort_order: 9},
      %{
        value: "nasarawa-eggon",
        label: "Nasarawa-Eggon",
        parent_value: "Nasarawa",
        sort_order: 10
      },
      %{value: "obi", label: "Obi", parent_value: "Nasarawa", sort_order: 11},
      %{value: "toto", label: "Toto", parent_value: "Nasarawa", sort_order: 12},
      %{value: "wamba", label: "Wamba", parent_value: "Nasarawa", sort_order: 13}
    ]
  },
  "Niger" => %{
    name: "Niger LGAs",
    slug: "ng-lgas-niger",
    description: "Local Government Areas in Niger State",
    values: [
      %{value: "agaie", label: "Agaie", parent_value: "Niger", sort_order: 1},
      %{value: "agwara", label: "Agwara", parent_value: "Niger", sort_order: 2},
      %{value: "bida", label: "Bida", parent_value: "Niger", sort_order: 3},
      %{value: "borgu", label: "Borgu", parent_value: "Niger", sort_order: 4},
      %{value: "bosso", label: "Bosso", parent_value: "Niger", sort_order: 5},
      %{value: "chanchaga", label: "Chanchaga", parent_value: "Niger", sort_order: 6},
      %{value: "edati", label: "Edati", parent_value: "Niger", sort_order: 7},
      %{value: "gbako", label: "Gbako", parent_value: "Niger", sort_order: 8},
      %{value: "gurara", label: "Gurara", parent_value: "Niger", sort_order: 9},
      %{value: "katcha", label: "Katcha", parent_value: "Niger", sort_order: 10},
      %{value: "kontagora", label: "Kontagora", parent_value: "Niger", sort_order: 11},
      %{value: "lapai", label: "Lapai", parent_value: "Niger", sort_order: 12},
      %{value: "lavun", label: "Lavun", parent_value: "Niger", sort_order: 13},
      %{value: "magama", label: "Magama", parent_value: "Niger", sort_order: 14},
      %{value: "mariga", label: "Mariga", parent_value: "Niger", sort_order: 15},
      %{value: "mashegu", label: "Mashegu", parent_value: "Niger", sort_order: 16},
      %{value: "mokwa", label: "Mokwa", parent_value: "Niger", sort_order: 17},
      %{value: "muya", label: "Muya", parent_value: "Niger", sort_order: 18},
      %{value: "pailoro", label: "Pailoro", parent_value: "Niger", sort_order: 19},
      %{value: "rafi", label: "Rafi", parent_value: "Niger", sort_order: 20},
      %{value: "rijau", label: "Rijau", parent_value: "Niger", sort_order: 21},
      %{value: "shiroro", label: "Shiroro", parent_value: "Niger", sort_order: 22},
      %{value: "suleja", label: "Suleja", parent_value: "Niger", sort_order: 23},
      %{value: "tafa", label: "Tafa", parent_value: "Niger", sort_order: 24},
      %{value: "wushishi", label: "Wushishi", parent_value: "Niger", sort_order: 25}
    ]
  },
  "Ogun" => %{
    name: "Ogun LGAs",
    slug: "ng-lgas-ogun",
    description: "Local Government Areas in Ogun State",
    values: [
      %{value: "abeokuta-north", label: "Abeokuta North", parent_value: "Ogun", sort_order: 1},
      %{value: "abeokuta-south", label: "Abeokuta South", parent_value: "Ogun", sort_order: 2},
      %{value: "ado-odo-ota", label: "Ado-Odo/Ota", parent_value: "Ogun", sort_order: 3},
      %{value: "yewa-north", label: "Yewa North", parent_value: "Ogun", sort_order: 4},
      %{value: "yewa-south", label: "Yewa South", parent_value: "Ogun", sort_order: 5},
      %{value: "ewekoro", label: "Ewekoro", parent_value: "Ogun", sort_order: 6},
      %{value: "ifo", label: "Ifo", parent_value: "Ogun", sort_order: 7},
      %{value: "ijebu-east", label: "Ijebu East", parent_value: "Ogun", sort_order: 8},
      %{value: "ijebu-north", label: "Ijebu North", parent_value: "Ogun", sort_order: 9},
      %{
        value: "ijebu-north-east",
        label: "Ijebu North East",
        parent_value: "Ogun",
        sort_order: 10
      },
      %{value: "ijebu-ode", label: "Ijebu Ode", parent_value: "Ogun", sort_order: 11},
      %{value: "ikenne", label: "Ikenne", parent_value: "Ogun", sort_order: 12},
      %{value: "imeko-afon", label: "Imeko-Afon", parent_value: "Ogun", sort_order: 13},
      %{value: "ipokia", label: "Ipokia", parent_value: "Ogun", sort_order: 14},
      %{value: "obafemi-owode", label: "Obafemi-Owode", parent_value: "Ogun", sort_order: 15},
      %{value: "ogun-waterside", label: "Ogun Waterside", parent_value: "Ogun", sort_order: 16},
      %{value: "odeda", label: "Odeda", parent_value: "Ogun", sort_order: 17},
      %{value: "odogbolu", label: "Odogbolu", parent_value: "Ogun", sort_order: 18},
      %{value: "remo-north", label: "Remo North", parent_value: "Ogun", sort_order: 19},
      %{value: "shagamu", label: "Shagamu", parent_value: "Ogun", sort_order: 20}
    ]
  },
  "Ondo" => %{
    name: "Ondo LGAs",
    slug: "ng-lgas-ondo",
    description: "Local Government Areas in Ondo State",
    values: [
      %{
        value: "akoko-north-east",
        label: "Akoko North East",
        parent_value: "Ondo",
        sort_order: 1
      },
      %{
        value: "akoko-north-west",
        label: "Akoko North West",
        parent_value: "Ondo",
        sort_order: 2
      },
      %{value: "akoko-south", label: "Akoko South", parent_value: "Ondo", sort_order: 3},
      %{value: "akure-east", label: "Akure East", parent_value: "Ondo", sort_order: 4},
      %{
        value: "akoko-south-west",
        label: "Akoko South West",
        parent_value: "Ondo",
        sort_order: 5
      },
      %{value: "akure-north", label: "Akure North", parent_value: "Ondo", sort_order: 6},
      %{value: "akure-south", label: "Akure South", parent_value: "Ondo", sort_order: 7},
      %{value: "ese-odo", label: "Ese-Odo", parent_value: "Ondo", sort_order: 8},
      %{value: "idanre", label: "Idanre", parent_value: "Ondo", sort_order: 9},
      %{value: "ifedore", label: "Ifedore", parent_value: "Ondo", sort_order: 10},
      %{value: "ilaje", label: "Ilaje", parent_value: "Ondo", sort_order: 11},
      %{value: "ile-oluji", label: "Ile-Oluji", parent_value: "Ondo", sort_order: 12},
      %{value: "okeigbo", label: "Okeigbo", parent_value: "Ondo", sort_order: 13},
      %{value: "irele", label: "Irele", parent_value: "Ondo", sort_order: 14},
      %{value: "odigbo", label: "Odigbo", parent_value: "Ondo", sort_order: 15},
      %{value: "okitipupa", label: "Okitipupa", parent_value: "Ondo", sort_order: 16},
      %{value: "ondo-east", label: "Ondo East", parent_value: "Ondo", sort_order: 17},
      %{value: "ondo-west", label: "Ondo West", parent_value: "Ondo", sort_order: 18},
      %{value: "ose", label: "Ose", parent_value: "Ondo", sort_order: 19},
      %{value: "owo", label: "Owo", parent_value: "Ondo", sort_order: 20}
    ]
  },
  "Osun" => %{
    name: "Osun LGAs",
    slug: "ng-lgas-osun",
    description: "Local Government Areas in Osun State",
    values: [
      %{value: "aiyedade", label: "Aiyedade", parent_value: "Osun", sort_order: 1},
      %{value: "aiyedire", label: "Aiyedire", parent_value: "Osun", sort_order: 2},
      %{value: "atakumosa-east", label: "Atakumosa East", parent_value: "Osun", sort_order: 3},
      %{value: "atakumosa-west", label: "Atakumosa West", parent_value: "Osun", sort_order: 4},
      %{value: "boluwaduro", label: "Boluwaduro", parent_value: "Osun", sort_order: 5},
      %{value: "boripe", label: "Boripe", parent_value: "Osun", sort_order: 6},
      %{value: "ede-north", label: "Ede North", parent_value: "Osun", sort_order: 7},
      %{value: "ede-south", label: "Ede South", parent_value: "Osun", sort_order: 8},
      %{value: "egbedore", label: "Egbedore", parent_value: "Osun", sort_order: 9},
      %{value: "ejigbo", label: "Ejigbo", parent_value: "Osun", sort_order: 10},
      %{value: "ife-central", label: "Ife Central", parent_value: "Osun", sort_order: 11},
      %{value: "ife-east", label: "Ife East", parent_value: "Osun", sort_order: 12},
      %{value: "ife-north", label: "Ife North", parent_value: "Osun", sort_order: 13},
      %{value: "ife-south", label: "Ife South", parent_value: "Osun", sort_order: 14},
      %{value: "ifedayo", label: "Ifedayo", parent_value: "Osun", sort_order: 15},
      %{value: "ifelodun", label: "Ifelodun", parent_value: "Osun", sort_order: 16},
      %{value: "ila", label: "Ila", parent_value: "Osun", sort_order: 17},
      %{value: "ilesha-east", label: "Ilesha East", parent_value: "Osun", sort_order: 18},
      %{value: "ilesha-west", label: "Ilesha West", parent_value: "Osun", sort_order: 19},
      %{value: "irepodun", label: "Irepodun", parent_value: "Osun", sort_order: 20},
      %{value: "irewole", label: "Irewole", parent_value: "Osun", sort_order: 21},
      %{value: "isokan", label: "Isokan", parent_value: "Osun", sort_order: 22},
      %{value: "iwo", label: "Iwo", parent_value: "Osun", sort_order: 23},
      %{value: "obokun", label: "Obokun", parent_value: "Osun", sort_order: 24},
      %{value: "odo-otin", label: "Odo-Otin", parent_value: "Osun", sort_order: 25},
      %{value: "ola-oluwa", label: "Ola-Oluwa", parent_value: "Osun", sort_order: 26},
      %{value: "olorunda", label: "Olorunda", parent_value: "Osun", sort_order: 27},
      %{value: "oriade", label: "Oriade", parent_value: "Osun", sort_order: 28},
      %{value: "orolu", label: "Orolu", parent_value: "Osun", sort_order: 29},
      %{value: "osogbo", label: "Osogbo", parent_value: "Osun", sort_order: 30}
    ]
  },
  "Oyo" => %{
    name: "Oyo LGAs",
    slug: "ng-lgas-oyo",
    description: "Local Government Areas in Oyo State",
    values: [
      %{value: "afijio", label: "Afijio", parent_value: "Oyo", sort_order: 1},
      %{value: "akinyele", label: "Akinyele", parent_value: "Oyo", sort_order: 2},
      %{value: "atiba", label: "Atiba", parent_value: "Oyo", sort_order: 3},
      %{value: "atisbo", label: "Atisbo", parent_value: "Oyo", sort_order: 4},
      %{value: "egbeda", label: "Egbeda", parent_value: "Oyo", sort_order: 5},
      %{value: "ibadan-central", label: "Ibadan Central", parent_value: "Oyo", sort_order: 6},
      %{value: "ibadan-north", label: "Ibadan North", parent_value: "Oyo", sort_order: 7},
      %{
        value: "ibadan-north-west",
        label: "Ibadan North West",
        parent_value: "Oyo",
        sort_order: 8
      },
      %{
        value: "ibadan-south-east",
        label: "Ibadan South East",
        parent_value: "Oyo",
        sort_order: 9
      },
      %{
        value: "ibadan-south-west",
        label: "Ibadan South West",
        parent_value: "Oyo",
        sort_order: 10
      },
      %{value: "ibarapa-central", label: "Ibarapa Central", parent_value: "Oyo", sort_order: 11},
      %{value: "ibarapa-east", label: "Ibarapa East", parent_value: "Oyo", sort_order: 12},
      %{value: "ibarapa-north", label: "Ibarapa North", parent_value: "Oyo", sort_order: 13},
      %{value: "ido", label: "Ido", parent_value: "Oyo", sort_order: 14},
      %{value: "irepo", label: "Irepo", parent_value: "Oyo", sort_order: 15},
      %{value: "iseyin", label: "Iseyin", parent_value: "Oyo", sort_order: 16},
      %{value: "itesiwaju", label: "Itesiwaju", parent_value: "Oyo", sort_order: 17},
      %{value: "iwajowa", label: "Iwajowa", parent_value: "Oyo", sort_order: 18},
      %{value: "kajola", label: "Kajola", parent_value: "Oyo", sort_order: 19},
      %{value: "lagelu", label: "Lagelu", parent_value: "Oyo", sort_order: 20},
      %{value: "ogbomosho-north", label: "Ogbomosho North", parent_value: "Oyo", sort_order: 21},
      %{value: "ogbomosho-south", label: "Ogbomosho South", parent_value: "Oyo", sort_order: 22},
      %{value: "ogo-oluwa", label: "Ogo Oluwa", parent_value: "Oyo", sort_order: 23},
      %{value: "olorunsogo", label: "Olorunsogo", parent_value: "Oyo", sort_order: 24},
      %{value: "oluyole", label: "Oluyole", parent_value: "Oyo", sort_order: 25},
      %{value: "ona-ara", label: "Ona-Ara", parent_value: "Oyo", sort_order: 26},
      %{value: "orelope", label: "Orelope", parent_value: "Oyo", sort_order: 27},
      %{value: "ori-ire", label: "Ori Ire", parent_value: "Oyo", sort_order: 28},
      %{value: "oyo-east", label: "Oyo East", parent_value: "Oyo", sort_order: 29},
      %{value: "oyo-west", label: "Oyo West", parent_value: "Oyo", sort_order: 30},
      %{value: "saki-east", label: "Saki East", parent_value: "Oyo", sort_order: 31},
      %{value: "saki-west", label: "Saki West", parent_value: "Oyo", sort_order: 32},
      %{value: "surulere", label: "Surulere", parent_value: "Oyo", sort_order: 33}
    ]
  },
  "Plateau" => %{
    name: "Plateau LGAs",
    slug: "ng-lgas-plateau",
    description: "Local Government Areas in Plateau State",
    values: [
      %{value: "barikin-ladi", label: "Barikin Ladi", parent_value: "Plateau", sort_order: 1},
      %{value: "bassa", label: "Bassa", parent_value: "Plateau", sort_order: 2},
      %{value: "bokkos", label: "Bokkos", parent_value: "Plateau", sort_order: 3},
      %{value: "jos-east", label: "Jos East", parent_value: "Plateau", sort_order: 4},
      %{value: "jos-north", label: "Jos North", parent_value: "Plateau", sort_order: 5},
      %{value: "jos-south", label: "Jos South", parent_value: "Plateau", sort_order: 6},
      %{value: "kanam", label: "Kanam", parent_value: "Plateau", sort_order: 7},
      %{value: "kanke", label: "Kanke", parent_value: "Plateau", sort_order: 8},
      %{value: "langtang-north", label: "Langtang North", parent_value: "Plateau", sort_order: 9},
      %{
        value: "langtang-south",
        label: "Langtang South",
        parent_value: "Plateau",
        sort_order: 10
      },
      %{value: "mangu", label: "Mangu", parent_value: "Plateau", sort_order: 11},
      %{value: "mikang", label: "Mikang", parent_value: "Plateau", sort_order: 12},
      %{value: "pankshin", label: "Pankshin", parent_value: "Plateau", sort_order: 13},
      %{value: "quaan-pan", label: "Qua'an Pan", parent_value: "Plateau", sort_order: 14},
      %{value: "riyom", label: "Riyom", parent_value: "Plateau", sort_order: 15},
      %{value: "shendam", label: "Shendam", parent_value: "Plateau", sort_order: 16},
      %{value: "wase", label: "Wase", parent_value: "Plateau", sort_order: 17}
    ]
  },
  "Rivers" => %{
    name: "Rivers LGAs",
    slug: "ng-lgas-rivers",
    description: "Local Government Areas in Rivers State",
    values: [
      %{value: "abua-odual", label: "Abua/Odual", parent_value: "Rivers", sort_order: 1},
      %{value: "ahoada-east", label: "Ahoada East", parent_value: "Rivers", sort_order: 2},
      %{value: "ahoada-west", label: "Ahoada West", parent_value: "Rivers", sort_order: 3},
      %{value: "akuku-toru", label: "Akuku Toru", parent_value: "Rivers", sort_order: 4},
      %{value: "andoni", label: "Andoni", parent_value: "Rivers", sort_order: 5},
      %{value: "asari-toru", label: "Asari-Toru", parent_value: "Rivers", sort_order: 6},
      %{value: "bonny", label: "Bonny", parent_value: "Rivers", sort_order: 7},
      %{value: "degema", label: "Degema", parent_value: "Rivers", sort_order: 8},
      %{value: "emohua", label: "Emohua", parent_value: "Rivers", sort_order: 9},
      %{value: "eleme", label: "Eleme", parent_value: "Rivers", sort_order: 10},
      %{value: "etche", label: "Etche", parent_value: "Rivers", sort_order: 11},
      %{value: "gokana", label: "Gokana", parent_value: "Rivers", sort_order: 12},
      %{value: "ikwerre", label: "Ikwerre", parent_value: "Rivers", sort_order: 13},
      %{value: "khana", label: "Khana", parent_value: "Rivers", sort_order: 14},
      %{value: "obio-akpor", label: "Obio/Akpor", parent_value: "Rivers", sort_order: 15},
      %{
        value: "ogba-egbema-ndoni",
        label: "Ogba/Egbema/Ndoni",
        parent_value: "Rivers",
        sort_order: 16
      },
      %{value: "ogu-bolo", label: "Ogu/Bolo", parent_value: "Rivers", sort_order: 17},
      %{value: "okrika", label: "Okrika", parent_value: "Rivers", sort_order: 18},
      %{value: "omumma", label: "Omumma", parent_value: "Rivers", sort_order: 19},
      %{value: "opobo-nkoro", label: "Opobo/Nkoro", parent_value: "Rivers", sort_order: 20},
      %{value: "oyigbo", label: "Oyigbo", parent_value: "Rivers", sort_order: 21},
      %{value: "port-harcourt", label: "Port-Harcourt", parent_value: "Rivers", sort_order: 22},
      %{value: "tai", label: "Tai", parent_value: "Rivers", sort_order: 23}
    ]
  },
  "Sokoto" => %{
    name: "Sokoto LGAs",
    slug: "ng-lgas-sokoto",
    description: "Local Government Areas in Sokoto State",
    values: [
      %{value: "binji", label: "Binji", parent_value: "Sokoto", sort_order: 1},
      %{value: "bodinga", label: "Bodinga", parent_value: "Sokoto", sort_order: 2},
      %{value: "dange-shnsi", label: "Dange-Shnsi", parent_value: "Sokoto", sort_order: 3},
      %{value: "gada", label: "Gada", parent_value: "Sokoto", sort_order: 4},
      %{value: "goronyo", label: "Goronyo", parent_value: "Sokoto", sort_order: 5},
      %{value: "gudu", label: "Gudu", parent_value: "Sokoto", sort_order: 6},
      %{value: "gawabawa", label: "Gawabawa", parent_value: "Sokoto", sort_order: 7},
      %{value: "illela", label: "Illela", parent_value: "Sokoto", sort_order: 8},
      %{value: "isa", label: "Isa", parent_value: "Sokoto", sort_order: 9},
      %{value: "kware", label: "Kware", parent_value: "Sokoto", sort_order: 10},
      %{value: "kebbe", label: "Kebbe", parent_value: "Sokoto", sort_order: 11},
      %{value: "rabah", label: "Rabah", parent_value: "Sokoto", sort_order: 12},
      %{value: "sabon-birni", label: "Sabon Birni", parent_value: "Sokoto", sort_order: 13},
      %{value: "shagari", label: "Shagari", parent_value: "Sokoto", sort_order: 14},
      %{value: "silame", label: "Silame", parent_value: "Sokoto", sort_order: 15},
      %{value: "sokoto-north", label: "Sokoto North", parent_value: "Sokoto", sort_order: 16},
      %{value: "sokoto-south", label: "Sokoto South", parent_value: "Sokoto", sort_order: 17},
      %{value: "tambuwal", label: "Tambuwal", parent_value: "Sokoto", sort_order: 18},
      %{value: "tangaza", label: "Tangaza", parent_value: "Sokoto", sort_order: 19},
      %{value: "tureta", label: "Tureta", parent_value: "Sokoto", sort_order: 20},
      %{value: "wamako", label: "Wamako", parent_value: "Sokoto", sort_order: 21},
      %{value: "wurno", label: "Wurno", parent_value: "Sokoto", sort_order: 22},
      %{value: "yabo", label: "Yabo", parent_value: "Sokoto", sort_order: 23}
    ]
  },
  "Taraba" => %{
    name: "Taraba LGAs",
    slug: "ng-lgas-taraba",
    description: "Local Government Areas in Taraba State",
    values: [
      %{value: "ardo-kola", label: "Ardo-Kola", parent_value: "Taraba", sort_order: 1},
      %{value: "bali", label: "Bali", parent_value: "Taraba", sort_order: 2},
      %{value: "donga", label: "Donga", parent_value: "Taraba", sort_order: 3},
      %{value: "gashaka", label: "Gashaka", parent_value: "Taraba", sort_order: 4},
      %{value: "cassol", label: "Cassol", parent_value: "Taraba", sort_order: 5},
      %{value: "ibi", label: "Ibi", parent_value: "Taraba", sort_order: 6},
      %{value: "jalingo", label: "Jalingo", parent_value: "Taraba", sort_order: 7},
      %{value: "karin-lamido", label: "Karin-Lamido", parent_value: "Taraba", sort_order: 8},
      %{value: "kurmi", label: "Kurmi", parent_value: "Taraba", sort_order: 9},
      %{value: "lau", label: "Lau", parent_value: "Taraba", sort_order: 10},
      %{value: "sardauna", label: "Sardauna", parent_value: "Taraba", sort_order: 11},
      %{value: "takum", label: "Takum", parent_value: "Taraba", sort_order: 12},
      %{value: "ussa", label: "Ussa", parent_value: "Taraba", sort_order: 13},
      %{value: "wukari", label: "Wukari", parent_value: "Taraba", sort_order: 14},
      %{value: "yorro", label: "Yorro", parent_value: "Taraba", sort_order: 15},
      %{value: "zing", label: "Zing", parent_value: "Taraba", sort_order: 16}
    ]
  },
  "Yobe" => %{
    name: "Yobe LGAs",
    slug: "ng-lgas-yobe",
    description: "Local Government Areas in Yobe State",
    values: [
      %{value: "bade", label: "Bade", parent_value: "Yobe", sort_order: 1},
      %{value: "bursari", label: "Bursari", parent_value: "Yobe", sort_order: 2},
      %{value: "damaturu", label: "Damaturu", parent_value: "Yobe", sort_order: 3},
      %{value: "fika", label: "Fika", parent_value: "Yobe", sort_order: 4},
      %{value: "fune", label: "Fune", parent_value: "Yobe", sort_order: 5},
      %{value: "geidam", label: "Geidam", parent_value: "Yobe", sort_order: 6},
      %{value: "gujba", label: "Gujba", parent_value: "Yobe", sort_order: 7},
      %{value: "gulani", label: "Gulani", parent_value: "Yobe", sort_order: 8},
      %{value: "jakusko", label: "Jakusko", parent_value: "Yobe", sort_order: 9},
      %{value: "karasuwa", label: "Karasuwa", parent_value: "Yobe", sort_order: 10},
      %{value: "karawa", label: "Karawa", parent_value: "Yobe", sort_order: 11},
      %{value: "machina", label: "Machina", parent_value: "Yobe", sort_order: 12},
      %{value: "nangere", label: "Nangere", parent_value: "Yobe", sort_order: 13},
      %{value: "nguru", label: "Nguru", parent_value: "Yobe", sort_order: 14},
      %{value: "potiskum", label: "Potiskum", parent_value: "Yobe", sort_order: 15},
      %{value: "tarmua", label: "Tarmua", parent_value: "Yobe", sort_order: 16},
      %{value: "yunusari", label: "Yunusari", parent_value: "Yobe", sort_order: 17},
      %{value: "yusufari", label: "Yusufari", parent_value: "Yobe", sort_order: 18}
    ]
  },
  "Zamfara" => %{
    name: "Zamfara LGAs",
    slug: "ng-lgas-zamfara",
    description: "Local Government Areas in Zamfara State",
    values: [
      %{value: "anka", label: "Anka", parent_value: "Zamfara", sort_order: 1},
      %{value: "bakura", label: "Bakura", parent_value: "Zamfara", sort_order: 2},
      %{value: "birnin-magaji", label: "Birnin Magaji", parent_value: "Zamfara", sort_order: 3},
      %{value: "bukkuyum", label: "Bukkuyum", parent_value: "Zamfara", sort_order: 4},
      %{value: "bungudu", label: "Bungudu", parent_value: "Zamfara", sort_order: 5},
      %{value: "gummi", label: "Gummi", parent_value: "Zamfara", sort_order: 6},
      %{value: "gusau", label: "Gusau", parent_value: "Zamfara", sort_order: 7},
      %{value: "kaura", label: "Kaura", parent_value: "Zamfara", sort_order: 8},
      %{value: "namoda", label: "Namoda", parent_value: "Zamfara", sort_order: 9},
      %{value: "maradun", label: "Maradun", parent_value: "Zamfara", sort_order: 10},
      %{value: "maru", label: "Maru", parent_value: "Zamfara", sort_order: 11},
      %{value: "shinkafi", label: "Shinkafi", parent_value: "Zamfara", sort_order: 12},
      %{value: "talata-mafara", label: "Talata Mafara", parent_value: "Zamfara", sort_order: 13},
      %{value: "tsafe", label: "Tsafe", parent_value: "Zamfara", sort_order: 14},
      %{value: "zurmi", label: "Zurmi", parent_value: "Zamfara", sort_order: 15}
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

IO.puts("\n✓ Done seeding Nigerian locations")
IO.puts("Total: 37 states, 774 LGAs\n")
