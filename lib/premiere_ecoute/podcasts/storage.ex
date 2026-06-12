defmodule PremiereEcoute.Podcasts.Storage do
  @moduledoc """
  Object-storage addressing for podcast audio.

  Audio files live in an S3-compatible object store (see docs/features/podcasts.md §6). This module
  owns the two pieces the rest of the app needs today: the immutable storage **key** for an episode
  and the **public URL** that key resolves to. The public base URL is configured per environment:

      config :premiere_ecoute, PremiereEcoute.Podcasts.Storage,
        public_base_url: "https://podcasts.premiere-ecoute.fr"

  Keys are write-once and stable so podcast apps never see an episode's enclosure URL change.

  Binary operations (`fetch/1`, `delete/1`) go through a swappable adapter behaviour so the rest of
  the app — notably episode ingestion — stays decoupled from the concrete S3 client. The adapter is
  provisioned per environment (the owner's S3-compatible provider); when none is configured the
  default `NotConfigured` adapter returns `{:error, :storage_not_configured}` rather than crashing:

      config :premiere_ecoute, PremiereEcoute.Podcasts.Storage,
        public_base_url: "https://podcasts.premiere-ecoute.fr",
        adapter: PremiereEcoute.Podcasts.Storage.S3
  """

  @callback fetch(key :: String.t()) :: {:ok, binary()} | {:error, term()}
  @callback put(key :: String.t(), bytes :: binary()) :: :ok | {:error, term()}
  @callback delete(key :: String.t()) :: :ok | {:error, term()}

  @doc "Fetches an object's bytes via the configured adapter."
  @spec fetch(String.t()) :: {:ok, binary()} | {:error, term()}
  def fetch(key), do: adapter().fetch(key)

  @doc "Stores an object's bytes via the configured adapter."
  @spec put(String.t(), binary()) :: :ok | {:error, term()}
  def put(key, bytes), do: adapter().put(key, bytes)

  @doc "Deletes an object via the configured adapter."
  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(key), do: adapter().delete(key)

  @doc "Returns the configured storage adapter module."
  @spec adapter() :: module()
  def adapter, do: config(:adapter, __MODULE__.NotConfigured)

  @doc "Returns the immutable storage key for an episode's audio file."
  @spec audio_key(integer(), String.t()) :: String.t()
  def audio_key(show_id, guid), do: "podcasts/#{show_id}/episodes/#{guid}.mp3"

  @doc "Returns the storage key for a show's cover image."
  @spec cover_key(integer(), String.t()) :: String.t()
  def cover_key(show_id, ext), do: "podcasts/#{show_id}/cover.#{normalize_ext(ext)}"

  @doc "Resolves a storage key to its public URL using the configured base URL."
  @spec public_url(String.t()) :: String.t()
  def public_url(key) do
    base = config(:public_base_url, "http://localhost:4000/uploads")
    String.trim_trailing(base, "/") <> "/" <> String.trim_leading(key, "/")
  end

  defp normalize_ext(ext), do: ext |> to_string() |> String.trim_leading(".") |> String.downcase()

  defp config(key, default) do
    :premiere_ecoute
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end
end
