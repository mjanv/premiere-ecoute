defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.Tracks do
  @moduledoc """
  Spotify tracks API.

  Fetches individual track data from Spotify API and parses into Track structs.
  """

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Discography.Album.Track

  @doc """
  Fetches a Spotify track by ID.

  Retrieves track metadata from Spotify API. Parses response into a Track struct.
  """
  @spec get_track(String.t()) :: {:ok, Track.t()} | {:error, term()}
  def get_track(track_id) when is_binary(track_id) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/tracks/#{track_id}")
    |> SpotifyApi.handle(200, &parse_track/1)
  end

  @spec parse_track(map()) :: Track.t()
  defp parse_track(data) do
    %Track{
      provider: :spotify,
      track_id: data["id"],
      album_id: data["album"]["id"],
      name: data["name"],
      track_number: data["track_number"] || 0,
      duration_ms: data["duration_ms"] || 0
    }
  end
end
