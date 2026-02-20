defmodule Angle.Catalog.OptionSetTest do
  use Angle.DataCase, async: true

  alias Angle.Catalog.OptionSet
  alias Angle.Catalog.OptionSetValue

  describe "read_with_descendants" do
    test "loads option set with children and their values" do
      # Create parent option set with values
      parent =
        OptionSet
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "States",
            slug: "states",
            description: "Nigerian states"
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      # Create parent values
      _parent_value1 =
        OptionSetValue
        |> Ash.Changeset.for_create(
          :create,
          %{
            option_set_id: parent.id,
            value: "lagos",
            label: "Lagos"
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      _parent_value2 =
        OptionSetValue
        |> Ash.Changeset.for_create(
          :create,
          %{
            option_set_id: parent.id,
            value: "abuja",
            label: "Abuja"
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      # Create child option set
      child =
        OptionSet
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Lagos LGAs",
            slug: "lagos-lgas",
            description: "LGAs in Lagos",
            parent_id: parent.id
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      # Create child values with parent_value reference
      _child_value1 =
        OptionSetValue
        |> Ash.Changeset.for_create(
          :create,
          %{
            option_set_id: child.id,
            value: "ikeja",
            label: "Ikeja",
            parent_set_id: parent.id,
            parent_value: "lagos"
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      _child_value2 =
        OptionSetValue
        |> Ash.Changeset.for_create(
          :create,
          %{
            option_set_id: child.id,
            value: "eti-osa",
            label: "Eti-Osa",
            parent_set_id: parent.id,
            parent_value: "lagos"
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      # Test read_with_descendants action
      result =
        OptionSet
        |> Ash.Query.for_read(:read_with_descendants, %{slug: "states"})
        |> Ash.read_one!()

      # Verify parent was loaded
      assert result.id == parent.id
      assert result.slug == "states"

      # Verify parent values were loaded
      assert length(result.option_set_values) == 2
      assert Enum.any?(result.option_set_values, &(&1.value == "lagos"))
      assert Enum.any?(result.option_set_values, &(&1.value == "abuja"))

      # Verify children were loaded
      assert length(result.children) == 1
      child_set = Enum.at(result.children, 0)
      assert child_set.id == child.id
      assert child_set.slug == "lagos-lgas"

      # Verify child values were loaded
      assert length(child_set.option_set_values) == 2
      assert Enum.any?(child_set.option_set_values, &(&1.value == "ikeja"))
      assert Enum.any?(child_set.option_set_values, &(&1.value == "eti-osa"))
    end

    test "returns nil for nonexistent slug" do
      result =
        OptionSet
        |> Ash.Query.for_read(:read_with_descendants, %{slug: "nonexistent"})
        |> Ash.read_one!()

      assert result == nil
    end
  end
end
