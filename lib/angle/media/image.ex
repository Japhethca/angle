defmodule Angle.Media.Image do
  use Ash.Resource,
    otp_app: :angle,
    domain: Angle.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "images"
    repo Angle.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :owner_type,
        :owner_id,
        :storage_key,
        :variants,
        :position,
        :file_size,
        :mime_type,
        :width,
        :height
      ]

      primary? true
    end

    destroy :destroy do
      primary? true
    end

    read :by_owner do
      argument :owner_type, :atom do
        allow_nil? false
        constraints one_of: [:item, :user_avatar, :store_logo]
      end

      argument :owner_id, :uuid do
        allow_nil? false
      end

      filter expr(owner_type == ^arg(:owner_type) and owner_id == ^arg(:owner_id))

      prepare build(sort: [position: :asc])
    end

    update :reorder do
      accept [:position]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action(:create) do
      authorize_if actor_present()
    end

    policy action(:destroy) do
      authorize_if actor_present()
    end

    policy action(:reorder) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :owner_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:item, :user_avatar, :store_logo]
    end

    attribute :owner_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :storage_key, :string do
      allow_nil? false
      public? true
    end

    attribute :variants, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :position, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :file_size, :integer do
      allow_nil? false
      public? true
    end

    attribute :mime_type, :string do
      allow_nil? false
      public? true
    end

    attribute :width, :integer do
      allow_nil? false
      public? true
    end

    attribute :height, :integer do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_position, [:owner_type, :owner_id, :position]
  end
end
