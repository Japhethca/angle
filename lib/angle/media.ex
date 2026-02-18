defmodule Angle.Media do
  use Ash.Domain,
    otp_app: :angle

  resources do
    resource Angle.Media.Image do
      define :get_image, action: :read, get_by: [:id]
      define :list_images_by_owner, action: :by_owner, args: [:owner_type, :owner_id]
      define :list_cover_images, action: :cover_images, args: [:item_ids]
      define :create_image, action: :create
      define :destroy_image, action: :destroy
      define :reorder_image, action: :reorder
    end
  end
end
