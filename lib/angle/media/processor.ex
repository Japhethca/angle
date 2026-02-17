defmodule Angle.Media.Processor do
  @moduledoc """
  Processes uploaded images into optimized webp variants using libvips.
  """

  @max_file_size 10 * 1024 * 1024
  @accepted_types ~w(image/jpeg image/png image/webp)

  @variants [
    {:thumbnail, 200, 80},
    {:medium, 600, 85},
    {:full, 1200, 90}
  ]

  def validate_file(path, mime_type) when mime_type in @accepted_types do
    # Don't trust client-supplied Content-Type alone; verify actual file bytes
    case Image.open(path) do
      {:ok, _image} -> :ok
      {:error, _} -> {:error, :invalid_type}
    end
  end

  def validate_file(_path, _mime_type), do: {:error, :invalid_type}

  def validate_file_size(size) when size <= @max_file_size, do: :ok
  def validate_file_size(_size), do: {:error, :file_too_large}

  def generate_variants(source_path) do
    with {:ok, image} <- Image.open(source_path) do
      {original_width, original_height, _bands} = Image.shape(image)
      tmp_dir = System.tmp_dir!()

      results =
        Enum.reduce_while(@variants, %{}, fn {name, max_width, quality}, acc ->
          output_path = Path.join(tmp_dir, "#{:erlang.unique_integer([:positive])}_#{name}.webp")

          case resize_and_save(image, output_path, max_width, quality, original_width) do
            :ok ->
              {:cont, Map.put(acc, name, output_path)}

            {:error, reason} ->
              Enum.each(acc, fn {_k, path} -> File.rm(path) end)
              {:halt, {:error, reason}}
          end
        end)

      case results do
        {:error, _} = error ->
          error

        variants_map ->
          {:ok,
           Map.merge(variants_map, %{
             original_width: original_width,
             original_height: original_height
           })}
      end
    end
  end

  def cleanup(result) do
    for {key, path} <- result, key in [:thumbnail, :medium, :full], is_binary(path) do
      File.rm(path)
    end

    :ok
  end

  defp resize_and_save(image, output_path, max_width, quality, original_width) do
    resized =
      if original_width > max_width do
        case Image.thumbnail(image, max_width) do
          {:ok, resized} -> resized
          {:error, _} = err -> err
        end
      else
        image
      end

    case resized do
      {:error, _} = err ->
        err

      resized_image ->
        case Image.write(resized_image, output_path, quality: quality) do
          {:ok, _} -> :ok
          {:error, _} = err -> err
        end
    end
  end
end
