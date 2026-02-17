defmodule Angle.Media.Storage.Mock do
  @moduledoc """
  Mock storage for tests. Always succeeds without touching any external service.
  """

  @behaviour Angle.Media.Storage

  @impl true
  def upload(_local_path, _remote_key, _content_type) do
    :ok
  end

  @impl true
  def delete(_remote_key) do
    :ok
  end
end
