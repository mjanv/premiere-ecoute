defmodule PremiereEcoute.Apis.DeezerApi.Playlists do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Apis.DeezerApi
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track

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
      added_at: nil
    }
  end

  defp parse_cover_url(data) do
    data["picture_medium"] || data["picture"] || data["picture_small"]
  end
end
