defmodule PremiereEcoute.Podcasts.Storage.Local do
  @moduledoc """
  Filesystem-backed storage adapter for development and tests.

  Writes objects under `priv/static/uploads/<key>` (served publicly by `Plug.Static` at `/uploads`),
  mirroring the existing image-upload pattern. Production swaps in an S3-compatible adapter; the
  behaviour keeps the rest of the app unchanged. Not suitable for multi-node / ephemeral hosts.
  """

  @behaviour PremiereEcoute.Podcasts.Storage

  @impl true
  def fetch(key) do
    case File.read(path(key)) do
      {:ok, bytes} -> {:ok, bytes}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def put(key, bytes) do
    dest = path(key)
    File.mkdir_p!(Path.dirname(dest))
    File.write(dest, bytes)
  end

  @impl true
  def delete(key) do
    _ = File.rm(path(key))
    :ok
  end

  defp path(key), do: Application.app_dir(:premiere_ecoute, Path.join("priv/static/uploads", key))
end
