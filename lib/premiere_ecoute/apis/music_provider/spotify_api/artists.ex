defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.Artists do
  @moduledoc """
  Spotify artists API.

  Fetches artist data and albums from Spotify API.
  """

  require Logger

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Parser
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Playlist

  @doc """
  Fetches an artist by Spotify ID.

  Returns an Artist struct with provider_ids and images populated.
  """
  @spec get_artist(String.t()) :: {:ok, Artist.t()} | {:error, term()}
  def get_artist(artist_id) when is_binary(artist_id) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/artists/#{artist_id}")
    |> SpotifyApi.handle(200, fn data ->
      %Artist{
        provider_ids: %{spotify: data["id"]},
        name: data["name"],
        images: Parser.parse_artist_images(data["images"])
      }
    end)
  end

  @doc """
  Fetches albums for an artist by Spotify ID.

  Returns a list of Album structs (without tracks).
  """
  @spec get_artist_albums(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_artist_albums(artist_id) when is_binary(artist_id) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/artists/#{artist_id}/albums?include_groups=album")
    |> SpotifyApi.handle(200, fn %{"items" => items} ->
      Enum.map(items, fn data ->
        %{
          provider_ids: %{spotify: data["id"]},
          name: data["name"],
          artists: Parser.parse_artists(data["artists"]),
          release_date: Parser.parse_release_date(data["release_date"]),
          cover_url: Parser.parse_album_cover_url(data["images"]),
          total_tracks: data["total_tracks"]
        }
      end)
    end)
  end

  @doc """
  Fetches an artist's top track.

  Retrieves the top tracks for a Spotify artist and returns the first one. Returns nil if no tracks found.
  """
  @spec get_artist_top_track(String.t()) :: {:ok, Playlist.Track.t() | nil} | {:error, term()}
  def get_artist_top_track(artist_id) when is_binary(artist_id) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/artists/#{artist_id}/top-tracks")
    |> SpotifyApi.handle(200, fn
      %{"tracks" => [track | _]} -> %Playlist.Track{track_id: track["id"], name: track["name"]}
      _ -> nil
    end)
  end
end
