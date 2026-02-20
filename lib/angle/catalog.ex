defmodule Angle.Catalog do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshAdmin.Domain, AshGraphql.Domain, AshJsonApi.Domain, AshTypescript.Rpc]

  admin do
    show? true
  end

  typescript_rpc do
    resource Angle.Catalog.Category do
      rpc_action :list_categories, :read
      rpc_action :create_category, :create

      typed_query :homepage_category, :read do
        ts_result_type_name "HomepageCategory"
        ts_fields_const_name "homepageCategoryFields"
        fields [:id, :name, :slug, :image_url]
      end

      typed_query :nav_category, :top_level do
        ts_result_type_name "NavCategory"
        ts_fields_const_name "navCategoryFields"
        fields [:id, :name, :slug, categories: [:id, :name, :slug]]
      end

      typed_query :listing_form_category, :top_level do
        ts_result_type_name "ListingFormCategory"
        ts_fields_const_name "listingFormCategoryFields"

        fields [
          :id,
          :name,
          :slug,
          attribute_schema: [:name, :type, :required, :description, :option_set_slug, :options],
          categories: [
            :id,
            :name,
            :slug,
            attribute_schema: [:name, :type, :required, :description, :option_set_slug, :options]
          ]
        ]
      end
    end

    resource Angle.Catalog.OptionSet do
      rpc_action :list_option_sets, :read_with_values
      rpc_action :read_option_set_with_descendants, :read_with_descendants
    end

    resource Angle.Catalog.OptionSetValue do
    end
  end

  resources do
    resource Angle.Catalog.Category
    resource Angle.Catalog.OptionSet
    resource Angle.Catalog.OptionSetValue
  end
end
