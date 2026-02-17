defmodule Angle.Catalog.CategoryField do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :type, :string do
      allow_nil? false
      default "string"
      public? true
    end

    attribute :required, :boolean do
      default false
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :option_set_slug, :string do
      public? true
    end

    attribute :options, {:array, :string} do
      public? true
    end
  end
end
