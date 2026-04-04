defmodule PremiereEcoute.Discography.Services.EnrichAlbum do
  @moduledoc """
  Enriches an album record with external links and provider IDs from third-party sources.

  Each source is fetched independently and stored only if the key is not already present.
  Sources already present are skipped without making an API call.

  The album's primary artist name (from `album.artist`) is used alongside the album title
  for all lookups to improve accuracy.
  """

  require Logger

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Supervisor

  @doc """
  Enriches an album with all available external data.

  Runs each enrichment source independently. Returns `{:ok, album}` with the
  final state of the album after all sources have been attempted.
  """
  @spec enrich_album(Album.t()) :: {:ok, Album.t()} | {:error, term()}
  def enrich_album(%Album{} = album) do
    external_links =
      [:wikipedia]
      |> Supervisor.async(fn k -> {k, enrich(k, album)} end)
      |> Enum.into(%{})
      |> then(&Map.merge(album.external_links, &1))

    provider_ids =
      [:spotify, :deezer, :tidal]
      |> Supervisor.async(fn k -> {k, enrich(k, album)} end)
      |> Enum.into(%{})
      |> then(&Map.merge(album.provider_ids, &1))

    Album.update(album, %{external_links: external_links, provider_ids: provider_ids})
  end

  defp enrich(:wikipedia, %Album{name: name} = album) do
    case Apis.wikipedia().search(artist: artist_name(album), album: name) do
      {:ok, [%{url: url} | _]} -> url
      {:ok, []} -> nil
      {:error, _reason} -> nil
    end
  end

  defp enrich(:deezer, %Album{name: name} = album) do
    case Apis.deezer().search_album(name, artist_name(album)) do
      {:ok, [%{deezer_id: deezer_id} | _]} -> deezer_id
      {:ok, []} -> nil
      {:error, _reason} -> nil
    end
  end

  defp enrich(:spotify, %Album{name: name} = album) do
    artist = artist_name(album)
    name_downcase = String.downcase(name)

    case Apis.spotify().search_albums("#{name} #{artist}") do
      {:ok, results} ->
        case Enum.find(results, &(String.downcase(&1.name) == name_downcase)) do
          %Album{provider_ids: %{spotify: id}} -> id
          nil -> nil
        end

      {:error, _reason} ->
        nil
    end
  end

  defp enrich(:tidal, %Album{name: name} = album) do
    artist = artist_name(album)

    case Apis.tidal().search_album(name, artist) do
      {:ok, [%{tidal_id: tidal_id} | _]} -> tidal_id
      {:ok, []} -> nil
      {:error, _reason} -> nil
    end
  end

  # Returns the primary artist name string, or empty string if not set
  defp artist_name(%Album{artist: %{name: name}}) when is_binary(name), do: name
  defp artist_name(%Album{artist: name}) when is_binary(name), do: name
  defp artist_name(_), do: ""
end
