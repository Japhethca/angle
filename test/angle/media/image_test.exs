defmodule Angle.Media.ImageTest do
  use Angle.DataCase, async: true

  alias Angle.Media.Image

  setup do
    user = Angle.Factory.create_user()
    item = Angle.Factory.create_item(%{created_by_id: user.id, title: "Test Item"})
    %{user: user, item: item}
  end

  describe "create action" do
    test "creates an image for an item", %{user: user, item: item} do
      assert {:ok, image} =
               Image
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   owner_type: :item,
                   owner_id: item.id,
                   storage_key: "items/#{item.id}/original.webp",
                   variants: %{
                     "thumbnail" => "items/#{item.id}/thumb.webp",
                     "medium" => "items/#{item.id}/medium.webp",
                     "full" => "items/#{item.id}/full.webp"
                   },
                   position: 0,
                   file_size: 150_000,
                   mime_type: "image/webp",
                   width: 1200,
                   height: 800
                 },
                 actor: user
               )
               |> Ash.create()

      assert image.owner_type == :item
      assert image.owner_id == item.id
      assert image.position == 0
      assert image.variants["thumbnail"] == "items/#{item.id}/thumb.webp"
    end

    test "creates an avatar image for a user", %{user: user} do
      assert {:ok, image} =
               Image
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   owner_type: :user_avatar,
                   owner_id: user.id,
                   storage_key: "avatars/#{user.id}/original.webp",
                   variants: %{
                     "thumbnail" => "avatars/#{user.id}/thumb.webp",
                     "medium" => "avatars/#{user.id}/medium.webp",
                     "full" => "avatars/#{user.id}/full.webp"
                   },
                   position: 0,
                   file_size: 50_000,
                   mime_type: "image/webp",
                   width: 400,
                   height: 400
                 },
                 actor: user
               )
               |> Ash.create()

      assert image.owner_type == :user_avatar
    end

    test "enforces unique position per owner", %{user: user, item: item} do
      base_attrs = %{
        owner_type: :item,
        owner_id: item.id,
        storage_key: "items/#{item.id}/original.webp",
        variants: %{},
        position: 0,
        file_size: 100,
        mime_type: "image/webp",
        width: 100,
        height: 100
      }

      {:ok, _} =
        Image
        |> Ash.Changeset.for_create(:create, base_attrs, actor: user)
        |> Ash.create()

      assert {:error, _} =
               Image
               |> Ash.Changeset.for_create(
                 :create,
                 %{base_attrs | storage_key: "items/#{item.id}/other.webp"},
                 actor: user
               )
               |> Ash.create()
    end
  end

  describe "destroy action" do
    test "deletes an image", %{user: user, item: item} do
      {:ok, image} =
        Image
        |> Ash.Changeset.for_create(
          :create,
          %{
            owner_type: :item,
            owner_id: item.id,
            storage_key: "items/#{item.id}/original.webp",
            variants: %{},
            position: 0,
            file_size: 100,
            mime_type: "image/webp",
            width: 100,
            height: 100
          },
          actor: user
        )
        |> Ash.create()

      assert :ok =
               image
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: user)
               |> Ash.destroy()
    end
  end

  describe "by_owner read action" do
    test "lists images for an owner sorted by position", %{user: user, item: item} do
      for i <- 0..2 do
        Image
        |> Ash.Changeset.for_create(
          :create,
          %{
            owner_type: :item,
            owner_id: item.id,
            storage_key: "items/#{item.id}/original_#{i}.webp",
            variants: %{},
            position: i,
            file_size: 100,
            mime_type: "image/webp",
            width: 100,
            height: 100
          },
          actor: user
        )
        |> Ash.create!()
      end

      images =
        Image
        |> Ash.Query.for_read(:by_owner, %{owner_type: :item, owner_id: item.id}, actor: user)
        |> Ash.read!()

      assert length(images) == 3
      assert Enum.map(images, & &1.position) == [0, 1, 2]
    end
  end
end
