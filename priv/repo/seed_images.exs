# Seeds images for all items using picsum.photos
#
# Run: mix run priv/repo/seed_images.exs
#
# Downloads random photos from picsum.photos, processes them through the same
# pipeline as UploadController (Processor -> Storage -> Ash create), and assigns
# 1-5 images per item.

require Ash.Query

alias Angle.Media
alias Angle.Media.Processor
alias Angle.Media.Storage

# ── Category → Picsum photo ID pools ──────────────────────────────────────────

category_photo_ids = %{
  "art" => [10, 15, 16, 20, 24, 36, 42, 43, 49, 54, 56, 65],
  "audio-headphones" => [60, 119, 160, 180, 201, 250, 256, 299, 337, 367, 403, 429],
  "collectibles" => [100, 106, 130, 133, 139, 164, 175, 191, 225, 237, 278, 308],
  "electronics" => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 26, 48],
  "furniture" => [37, 116, 117, 129, 177, 239, 271, 280, 282, 310, 322, 357],
  "jewelry" => [39, 64, 68, 77, 96, 103, 112, 152, 188, 198, 243, 264],
  "smartphones" => [11, 29, 44, 119, 160, 180, 201, 250, 256, 367, 403, 429],
  "sports" => [47, 58, 104, 121, 143, 157, 168, 203, 209, 217, 301, 368],
  "vehicles" => [111, 113, 122, 133, 135, 171, 183, 195, 214, 252, 316, 342]
}

fallback_photo_ids = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120]

# ── Download helper ───────────────────────────────────────────────────────────

download_image = fn photo_id ->
  url = "https://picsum.photos/id/#{photo_id}/1200/900"

  case Req.get(url, max_redirects: 5) do
    {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) and byte_size(body) > 0 ->
      tmp_path =
        Path.join(
          System.tmp_dir!(),
          "seed_#{photo_id}_#{:erlang.unique_integer([:positive])}.jpg"
        )

      File.write!(tmp_path, body)
      Process.sleep(200)
      {:ok, tmp_path}

    {:ok, %Req.Response{status: status}} ->
      {:error, "HTTP #{status} for photo #{photo_id}"}

    {:error, reason} ->
      {:error, "Download failed for photo #{photo_id}: #{inspect(reason)}"}
  end
end

# ── Process and store helper ──────────────────────────────────────────────────

process_and_store = fn tmp_path, item_id, position, actor ->
  image_id = Ecto.UUID.generate()
  storage_prefix = "items/#{item_id}/#{image_id}"

  with {:ok, variant_result} <- Processor.generate_variants(tmp_path) do
    # Upload variants (thumbnail, medium, full)
    variant_urls =
      variant_result
      |> Enum.filter(fn {name, _} -> name in [:thumbnail, :medium, :full] end)
      |> Enum.reduce(%{}, fn {variant_name, local_path}, acc ->
        remote_key = "#{storage_prefix}/#{variant_name}.webp"
        :ok = Storage.upload(local_path, remote_key, "image/webp")
        Map.put(acc, to_string(variant_name), Storage.url(remote_key))
      end)

    # Upload original
    original_key = "#{storage_prefix}/original.jpg"
    :ok = Storage.upload(tmp_path, original_key, "image/jpeg")

    {:ok, %{size: file_size}} = File.stat(tmp_path)

    # Create DB record
    result =
      Media.Image
      |> Ash.Changeset.for_create(
        :create,
        %{
          owner_type: :item,
          owner_id: item_id,
          storage_key: original_key,
          variants: variant_urls,
          position: position,
          file_size: file_size,
          mime_type: "image/jpeg",
          width: variant_result.original_width,
          height: variant_result.original_height
        },
        actor: actor
      )
      |> Ash.create()

    Processor.cleanup(variant_result)
    File.rm(tmp_path)

    result
  else
    {:error, reason} ->
      File.rm(tmp_path)
      {:error, reason}
  end
end

# ── Main loop ─────────────────────────────────────────────────────────────────

IO.puts("\nLoading items...")

items =
  Angle.Inventory.Item
  |> Ash.Query.load(:category)
  |> Ash.read!(authorize?: false)

IO.puts("Found #{length(items)} items\n")

# Pre-load unique creator users
creator_ids = items |> Enum.map(& &1.created_by_id) |> Enum.uniq()

users_by_id =
  Angle.Accounts.User
  |> Ash.Query.filter(id in ^creator_ids)
  |> Ash.read!(authorize?: false)
  |> Enum.into(%{}, fn user -> {user.id, user} end)

items
|> Enum.with_index()
|> Enum.each(fn {item, index} ->
  target_count = rem(index, 5) + 1

  # Check existing images
  existing_images =
    Media.Image
    |> Ash.Query.for_read(:by_owner, %{owner_type: :item, owner_id: item.id}, authorize?: false)
    |> Ash.read!()

  existing_count = length(existing_images)

  if existing_count >= target_count do
    IO.puts(
      "[#{index + 1}/#{length(items)}] #{item.title} - already has #{existing_count} images, skipping"
    )
  else
    needed = target_count - existing_count

    next_pos =
      if existing_images == [],
        do: 0,
        else: (existing_images |> Enum.map(& &1.position) |> Enum.max()) + 1

    category_slug = if item.category, do: item.category.slug, else: nil
    photo_pool = Map.get(category_photo_ids, category_slug, fallback_photo_ids)

    actor = Map.fetch!(users_by_id, item.created_by_id)

    IO.write("[#{index + 1}/#{length(items)}] #{item.title} - adding #{needed} image(s)...")

    Enum.each(0..(needed - 1), fn i ->
      photo_id = Enum.at(photo_pool, rem(existing_count + i, length(photo_pool)))
      position = next_pos + i

      case download_image.(photo_id) do
        {:ok, tmp_path} ->
          case process_and_store.(tmp_path, item.id, position, actor) do
            {:ok, _image} ->
              IO.write(" ok")

            {:error, reason} ->
              IO.write(" FAIL(#{inspect(reason)})")
          end

        {:error, reason} ->
          IO.write(" SKIP(#{reason})")
      end
    end)

    IO.puts("")
  end
end)

IO.puts("\nDone! Image seeding completed.")
