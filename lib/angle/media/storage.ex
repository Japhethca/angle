defmodule Angle.Media.Storage do
  @moduledoc """
  Behaviour for image storage backends. Dispatches to configured module.
  """

  @callback upload(local_path :: String.t(), remote_key :: String.t(), content_type :: String.t()) ::
              :ok | {:error, term()}

  @callback delete(remote_key :: String.t()) :: :ok | {:error, term()}

  def upload(local_path, remote_key, content_type) do
    impl().upload(local_path, remote_key, content_type)
  end

  def delete(remote_key) do
    impl().delete(remote_key)
  end

  def url(remote_key) do
    config = Application.get_env(:angle, Angle.Media)
    "#{config[:base_url]}/#{remote_key}"
  end

  defp impl do
    config = Application.get_env(:angle, Angle.Media)
    config[:storage_module] || Angle.Media.Storage.R2
  end
end
