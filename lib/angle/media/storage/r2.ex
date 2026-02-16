defmodule Angle.Media.Storage.R2 do
  @moduledoc """
  Cloudflare R2 storage backend (S3-compatible).
  """

  @behaviour Angle.Media.Storage

  @impl true
  def upload(local_path, remote_key, content_type) do
    body = File.read!(local_path)

    bucket()
    |> ExAws.S3.put_object(remote_key, body, content_type: content_type, acl: :public_read)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(remote_key) do
    bucket()
    |> ExAws.S3.delete_object(remote_key)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp bucket do
    config = Application.get_env(:angle, Angle.Media)
    config[:bucket]
  end
end
