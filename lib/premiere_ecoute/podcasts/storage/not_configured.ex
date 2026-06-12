defmodule PremiereEcoute.Podcasts.Storage.NotConfigured do
  @moduledoc """
  Fallback storage adapter used until an S3-compatible adapter is configured.

  Returns `{:error, :storage_not_configured}` for every binary operation so the app degrades
  gracefully (e.g. episode ingestion marks the episode failed) instead of crashing.
  """

  @behaviour PremiereEcoute.Podcasts.Storage

  import Plug.Conn

  @impl true
  def fetch(_key), do: {:error, :storage_not_configured}

  @impl true
  def put(_key, _bytes), do: {:error, :storage_not_configured}

  @impl true
  def delete(_key), do: {:error, :storage_not_configured}

  @impl true
  def send_object(conn, _key, _content_type), do: send_resp(conn, 503, "Storage not configured")
end
