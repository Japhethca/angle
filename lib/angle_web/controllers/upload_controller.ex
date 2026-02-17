defmodule AngleWeb.UploadController do
  use AngleWeb, :controller

  require Ash.Query

  alias Angle.Media
  alias Angle.Media.Processor
  alias Angle.Media.Storage

  @max_item_images 10
  @single_image_types [:user_avatar, :store_logo]

  # POST /uploads
  def create(conn, %{"file" => %Plug.Upload{} = upload} = params) do
    user = conn.assigns.current_user

    with {:ok, owner_type} <- parse_owner_type(params["owner_type"]),
         {:ok, owner_id} <- parse_uuid(params["owner_id"]),
         :ok <- verify_ownership(user, owner_type, owner_id),
         :ok <- Processor.validate_file(upload.path, upload.content_type),
         :ok <- validate_file_size(upload.path),
         :ok <- check_image_limit(owner_type, owner_id) do
      # For single-image types, delete existing before creating new
      if owner_type in @single_image_types do
        delete_existing_images(owner_type, owner_id, user)
      end

      case process_and_store(upload, owner_type, owner_id, user) do
        {:ok, image} ->
          conn
          |> put_status(201)
          |> json(serialize_image(image))

        {:error, reason} ->
          conn
          |> put_status(422)
          |> json(%{error: format_error(reason)})
      end
    else
      {:error, :invalid_owner_type} ->
        conn |> put_status(422) |> json(%{error: "Invalid owner type"})

      {:error, :invalid_uuid} ->
        conn |> put_status(422) |> json(%{error: "Invalid owner ID"})

      {:error, :forbidden} ->
        conn |> put_status(403) |> json(%{error: "Not authorized"})

      {:error, :invalid_type} ->
        conn |> put_status(422) |> json(%{error: "Invalid file type. Accepted: JPEG, PNG, WebP"})

      {:error, :file_too_large} ->
        conn |> put_status(422) |> json(%{error: "File too large. Maximum 10MB"})

      {:error, :image_limit_reached} ->
        conn
        |> put_status(422)
        |> json(%{error: "Maximum #{@max_item_images} images per item"})
    end
  end

  def create(conn, _params) do
    conn |> put_status(422) |> json(%{error: "Missing file upload"})
  end

  # DELETE /uploads/:id
  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, image} <- get_image(id),
         :ok <- verify_image_ownership(user, image) do
      # Delete variants from storage
      delete_image_from_storage(image)

      # Delete DB record
      image
      |> Ash.Changeset.for_destroy(:destroy, %{}, actor: user)
      |> Ash.destroy!()

      send_resp(conn, 204, "")
    else
      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "Image not found"})

      {:error, :forbidden} ->
        conn |> put_status(403) |> json(%{error: "Not authorized"})
    end
  end

  # PATCH /uploads/reorder
  def reorder(conn, %{"item_id" => item_id, "image_ids" => image_ids})
      when is_list(image_ids) do
    user = conn.assigns.current_user

    with {:ok, item_uuid} <- parse_uuid(item_id),
         :ok <- verify_ownership(user, :item, item_uuid),
         {:ok, loaded_images} <- load_images_by_ids(image_ids) do
      case reorder_images_in_transaction(loaded_images, user) do
        {:ok, images} ->
          conn
          |> put_status(200)
          |> json(%{images: Enum.map(images, &serialize_image/1)})

        {:error, reason} ->
          conn
          |> put_status(422)
          |> json(%{error: format_error(reason)})
      end
    else
      {:error, :invalid_uuid} ->
        conn |> put_status(422) |> json(%{error: "Invalid item ID"})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "Image not found"})

      {:error, :forbidden} ->
        conn |> put_status(403) |> json(%{error: "Not authorized"})
    end
  end

  def reorder(conn, _params) do
    conn |> put_status(422) |> json(%{error: "Missing item_id or image_ids"})
  end

  # Private helpers

  defp parse_owner_type("item"), do: {:ok, :item}
  defp parse_owner_type("user_avatar"), do: {:ok, :user_avatar}
  defp parse_owner_type("store_logo"), do: {:ok, :store_logo}
  defp parse_owner_type(_), do: {:error, :invalid_owner_type}

  defp parse_uuid(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, :invalid_uuid}
    end
  end

  defp parse_uuid(_), do: {:error, :invalid_uuid}

  defp verify_ownership(user, :item, owner_id) do
    case Ash.get(Angle.Inventory.Item, owner_id, authorize?: false) do
      {:ok, item} ->
        if item.created_by_id == user.id, do: :ok, else: {:error, :forbidden}

      {:error, _} ->
        {:error, :forbidden}
    end
  end

  defp verify_ownership(user, :user_avatar, owner_id) do
    if user.id == owner_id, do: :ok, else: {:error, :forbidden}
  end

  defp verify_ownership(user, :store_logo, owner_id) do
    case Ash.get(Angle.Accounts.StoreProfile, owner_id, authorize?: false) do
      {:ok, profile} ->
        if profile.user_id == user.id, do: :ok, else: {:error, :forbidden}

      {:error, _} ->
        {:error, :forbidden}
    end
  end

  defp validate_file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> Processor.validate_file_size(size)
      {:error, _} -> {:error, :file_too_large}
    end
  end

  defp check_image_limit(owner_type, _owner_id) when owner_type in @single_image_types, do: :ok

  defp check_image_limit(:item, owner_id) do
    query =
      Media.Image
      |> Ash.Query.filter(owner_type == :item and owner_id == ^owner_id)

    count = Ash.count!(query, authorize?: false)

    if count < @max_item_images, do: :ok, else: {:error, :image_limit_reached}
  end

  defp next_position(owner_type, owner_id) do
    images =
      Media.Image
      |> Ash.Query.for_read(:by_owner, %{owner_type: owner_type, owner_id: owner_id},
        authorize?: false
      )
      |> Ash.read!()

    case images do
      [] -> 0
      imgs -> (imgs |> Enum.map(& &1.position) |> Enum.max()) + 1
    end
  end

  defp delete_existing_images(owner_type, owner_id, user) do
    images =
      Media.Image
      |> Ash.Query.for_read(:by_owner, %{owner_type: owner_type, owner_id: owner_id},
        authorize?: false
      )
      |> Ash.read!()

    Enum.each(images, fn image ->
      delete_image_from_storage(image)

      image
      |> Ash.Changeset.for_destroy(:destroy, %{}, actor: user)
      |> Ash.destroy!()
    end)
  end

  defp process_and_store(upload, owner_type, owner_id, user) do
    storage_prefix = storage_prefix(owner_type, owner_id)

    with {:ok, variant_result} <- Processor.generate_variants(upload.path) do
      # Upload variants to storage
      variant_urls =
        for {variant_name, local_path} <- variant_result,
            variant_name in [:thumbnail, :medium, :full],
            into: %{} do
          remote_key = "#{storage_prefix}/#{variant_name}.webp"
          :ok = Storage.upload(local_path, remote_key, "image/webp")
          {to_string(variant_name), Storage.url(remote_key)}
        end

      # Upload original
      original_key = "#{storage_prefix}/original#{Path.extname(upload.filename)}"
      :ok = Storage.upload(upload.path, original_key, upload.content_type)

      # Clean up temp files
      Processor.cleanup(variant_result)

      position = next_position(owner_type, owner_id)
      file_size = File.stat!(upload.path).size

      # Create DB record
      Media.Image
      |> Ash.Changeset.for_create(
        :create,
        %{
          owner_type: owner_type,
          owner_id: owner_id,
          storage_key: original_key,
          variants: variant_urls,
          position: position,
          file_size: file_size,
          mime_type: upload.content_type,
          width: variant_result.original_width,
          height: variant_result.original_height
        },
        actor: user
      )
      |> Ash.create()
    end
  end

  defp storage_prefix(:item, owner_id), do: "items/#{owner_id}"
  defp storage_prefix(:user_avatar, owner_id), do: "avatars/#{owner_id}"
  defp storage_prefix(:store_logo, owner_id), do: "logos/#{owner_id}"

  defp load_images_by_ids(image_ids) do
    Enum.reduce_while(image_ids, {:ok, []}, fn id, {:ok, acc} ->
      case get_image(id) do
        {:ok, image} -> {:cont, {:ok, acc ++ [image]}}
        {:error, :not_found} -> {:halt, {:error, :not_found}}
      end
    end)
  end

  defp reorder_images_in_transaction(loaded_images, user) do
    Angle.Repo.transaction(fn ->
      # First pass: set all positions to negative temporaries to avoid unique constraint conflicts
      Enum.with_index(loaded_images, fn image, idx ->
        image
        |> Ash.Changeset.for_update(:reorder, %{position: -(idx + 1)}, actor: user)
        |> Ash.update!()
      end)

      # Second pass: set to actual desired positions
      loaded_images
      |> Enum.with_index()
      |> Enum.map(fn {image, position} ->
        {:ok, fresh_image} = get_image(image.id)

        fresh_image
        |> Ash.Changeset.for_update(:reorder, %{position: position}, actor: user)
        |> Ash.update!()
      end)
    end)
  end

  defp get_image(id) do
    case Ash.get(Media.Image, id, authorize?: false) do
      {:ok, image} -> {:ok, image}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp verify_image_ownership(user, image) do
    case image.owner_type do
      :item ->
        verify_ownership(user, :item, image.owner_id)

      :user_avatar ->
        verify_ownership(user, :user_avatar, image.owner_id)

      :store_logo ->
        verify_ownership(user, :store_logo, image.owner_id)
    end
  end

  defp delete_image_from_storage(image) do
    # Delete original
    Storage.delete(image.storage_key)

    # Delete variants
    Enum.each(image.variants, fn {_name, url} ->
      # Extract key from URL
      config = Application.get_env(:angle, Angle.Media)
      base_url = config[:base_url]

      key =
        if String.starts_with?(url, base_url) do
          String.replace_prefix(url, "#{base_url}/", "")
        else
          url
        end

      Storage.delete(key)
    end)
  end

  defp serialize_image(image) do
    %{
      "id" => image.id,
      "owner_type" => to_string(image.owner_type),
      "owner_id" => image.owner_id,
      "variants" => image.variants,
      "position" => image.position,
      "width" => image.width,
      "height" => image.height,
      "storage_key" => image.storage_key
    }
  end

  defp format_error(%Ash.Error.Invalid{} = error) do
    Ash.Error.Invalid.message(error)
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason) when is_atom(reason), do: to_string(reason)
  defp format_error(_), do: "Upload failed"
end
