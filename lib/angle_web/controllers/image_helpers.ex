defmodule AngleWeb.ImageHelpers do
  @moduledoc """
  Shared helpers for loading cover images and attaching them to item data
  loaded from AshTypescript typed queries.
  """

  @doc """
  Given a list of items (maps with "id" keys), loads the cover image
  (position 0) for each item and merges it as a "coverImage" key.
  """
  @spec attach_cover_images(list(map())) :: list(map())
  def attach_cover_images([]), do: []

  def attach_cover_images(items) when is_list(items) do
    item_ids = Enum.map(items, &get_item_id/1)

    {:ok, images} = Angle.Media.list_cover_images(item_ids, authorize?: false)

    cover_images =
      Map.new(images, fn img ->
        {img.owner_id, serialize_image(img)}
      end)

    Enum.map(items, fn item ->
      item_id = get_item_id(item)

      case item do
        %{__struct__: _} -> Map.put(item, :cover_image, Map.get(cover_images, item_id))
        %{} -> Map.put(item, "coverImage", Map.get(cover_images, item_id))
      end
    end)
  end

  @doc """
  Given a list of records with nested item maps (e.g. bids or orders),
  loads cover images for the nested items and attaches them.
  The `item_key` parameter is the string key where the item map lives
  (e.g. "item" for bid["item"]).
  """
  @spec attach_nested_cover_images(list(map()), String.t()) :: list(map())
  def attach_nested_cover_images([], _item_key), do: []

  def attach_nested_cover_images(records, item_key) when is_list(records) do
    item_ids =
      records
      |> Enum.map(fn record -> get_in(record, [item_key, "id"]) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if item_ids == [] do
      records
    else
      {:ok, images} = Angle.Media.list_cover_images(item_ids, authorize?: false)

      cover_images =
        Map.new(images, fn img ->
          {img.owner_id, serialize_image(img)}
        end)

      Enum.map(records, fn record ->
        item_id = get_in(record, [item_key, "id"])

        case item_id do
          nil ->
            record

          id ->
            item_with_image =
              Map.put(record[item_key], "coverImage", Map.get(cover_images, id))

            Map.put(record, item_key, item_with_image)
        end
      end)
    end
  end

  @doc """
  Loads all images for a single item, sorted by position.
  Returns a list of serialized image maps.
  """
  @spec load_item_images(String.t()) :: list(map())
  def load_item_images(item_id) when is_binary(item_id) do
    {:ok, images} = Angle.Media.list_images_by_owner(:item, item_id, authorize?: false)
    Enum.map(images, &serialize_image/1)
  end

  def load_item_images(_), do: []

  @doc """
  Returns the thumbnail URL for a given owner, or nil if no image exists.
  Used for avatars, store logos, or any single-image owner type.
  """
  @spec load_owner_thumbnail_url(atom(), String.t()) :: String.t() | nil
  def load_owner_thumbnail_url(owner_type, owner_id) do
    {:ok, images} = Angle.Media.list_images_by_owner(owner_type, owner_id, authorize?: false)

    case images do
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

  # Private helper to extract item ID from structs or maps with string/atom keys
  defp get_item_id(item) do
    cond do
      is_struct(item) -> item.id
      is_map_key(item, "id") -> item["id"]
      is_map_key(item, :id) -> item[:id]
      true -> nil
    end
  end
end
