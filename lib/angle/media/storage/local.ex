defmodule Angle.Media.Storage.Local do
  @moduledoc """
  Local filesystem storage backend for development.
  Writes files to priv/static/uploads/ and serves them via Plug.Static.
  """

  @behaviour Angle.Media.Storage

  @impl true
  def upload(local_path, remote_key, _content_type) do
    dest = dest_path(remote_key)
    dest |> Path.dirname() |> File.mkdir_p!()

    case File.cp(local_path, dest) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(remote_key) do
    dest = dest_path(remote_key)

    case File.rm(dest) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp dest_path(remote_key) do
    Path.join(uploads_dir(), remote_key)
  end

  defp uploads_dir do
    Path.join(:code.priv_dir(:angle), "static/uploads")
  end
end
