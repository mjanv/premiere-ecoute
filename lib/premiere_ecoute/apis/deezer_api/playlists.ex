defmodule PremiereEcoute.Apis.DeezerApi.Playlists do
  @moduledoc """
  Deezer playlists API.

  Fetches playlist data from Deezer API and parses into Playlist aggregates with tracks.
  """

  require Logger

  alias PremiereEcoute.Apis.DeezerApi
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track

  @doc """
  Fetches a Deezer playlist by ID.

  Retrieves playlist metadata and tracks from Deezer API. Parses response into Playlist aggregate with tracks.
  """
  @spec get_playlist(String.t()) :: {:ok, Playlist.t()} | {:error, term()}
  def get_playlist(playlist_id) when is_binary(playlist_id) do
    DeezerApi.api()
    |> DeezerApi.get(url: "/playlist/#{playlist_id}")
    |> DeezerApi.handle(200, &parse_playlist/1)
  end

  def parse_playlist(data) do
    %Playlist{
      provider: :deezer,
      playlist_id: to_string(data["id"]),
      owner_name: data["creator"]["name"],
      owner_id: to_string(data["creator"]["id"]),
      title: data["title"],
      cover_url: parse_cover_url(data),
      tracks: Enum.map(data["tracks"]["data"], &parse_track/1)
    }
  end

  defp parse_track(data) do
    %Track{
      provider: :deezer,
      track_id: to_string(data["id"]),
      album_id: to_string(data["album"]["id"]),
      user_id: nil,
      name: data["title"],
      artist: data["artist"]["name"],
      duration_ms: (data["duration"] || 0) * 1000,
      added_at: nil,
      release_date: ~D[1900-01-01]
    }
  end

  defp parse_cover_url(data) do
    data["picture_medium"] || data["picture"] || data["picture_small"]
  end
end
