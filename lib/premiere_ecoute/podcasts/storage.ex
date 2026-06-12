defmodule PremiereEcoute.Podcasts.Storage do
  @moduledoc """
  Object-storage addressing for podcast audio.

  Audio files live in an S3-compatible object store (see docs/features/podcasts.md §6). This module
  owns the two pieces the rest of the app needs today: the immutable storage **key** for an episode
  and the **public URL** that key resolves to. The public base URL is configured per environment:

      config :premiere_ecoute, PremiereEcoute.Podcasts.Storage,
        public_base_url: "https://podcasts.premiere-ecoute.fr"

  Keys are write-once and stable so podcast apps never see an episode's enclosure URL change.
  Upload (presigned PUT) and server-side fetch/delete are intentionally left to a later increment
  that introduces the concrete S3 client; this module stays dependency-free and pure.
  """

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
