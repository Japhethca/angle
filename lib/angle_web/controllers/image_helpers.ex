defmodule AngleWeb.ImageHelpers do
  @moduledoc """
  Shared helpers for loading cover images and attaching them to item data
  loaded from AshTypescript typed queries.
  """

  require Ash.Query

  @doc """
  Given a list of items (maps with "id" keys), loads the cover image
  (position 0) for each item and merges it as a "coverImage" key.
  """
  @spec attach_cover_images(list(map())) :: list(map())
  def attach_cover_images([]), do: []

  def attach_cover_images(items) when is_list(items) do
    item_ids = Enum.map(items, fn item -> item["id"] end)

    cover_images =
      Angle.Media.Image
      |> Ash.Query.filter(owner_type == :item and owner_id in ^item_ids and position == 0)
      |> Ash.read!(authorize?: false)
      |> Map.new(fn img ->
        {img.owner_id, serialize_image(img)}
      end)

    Enum.map(items, fn item ->
      Map.put(item, "coverImage", Map.get(cover_images, item["id"]))
    end)
  end

  @doc """
  Loads all images for a single item, sorted by position.
  Returns a list of serialized image maps.
  """
  @spec load_item_images(String.t()) :: list(map())
  def load_item_images(item_id) when is_binary(item_id) do
    Angle.Media.Image
    |> Ash.Query.for_read(:by_owner, %{owner_type: :item, owner_id: item_id}, authorize?: false)
    |> Ash.read!()
    |> Enum.map(&serialize_image/1)
  end

  def load_item_images(_), do: []

  @doc """
  Returns the thumbnail URL for a given owner, or nil if no image exists.
  Used for avatars, store logos, or any single-image owner type.
  """
  @spec load_owner_thumbnail_url(atom(), String.t()) :: String.t() | nil
  def load_owner_thumbnail_url(owner_type, owner_id) do
    case Angle.Media.Image
         |> Ash.Query.for_read(:by_owner, %{owner_type: owner_type, owner_id: owner_id},
           authorize?: false
         )
         |> Ash.read!() do
      [image | _] ->
        case image.variants do
          %{"thumbnail" => url} -> url
          _ -> nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Serializes an image record to a map suitable for JSON/Inertia props.
  """
  def serialize_image(img) do
    %{
      "id" => img.id,
      "variants" => img.variants,
      "position" => img.position,
      "width" => img.width,
      "height" => img.height
    }
  end
end
