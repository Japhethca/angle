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
    end
  end

  resources do
    resource Angle.Catalog.Category
    resource Angle.Catalog.OptionSet
    resource Angle.Catalog.OptionSetValue
  end
end
