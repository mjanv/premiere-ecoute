defmodule PremiereEcoute.Festivals.Services.TrackSearch do
  @moduledoc false

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Festivals.Festival

  def create_festival_playlist(scope, %Festival{name: name}, tracks) do
    with playlist <- %LibraryPlaylist{title: name, description: "", public: false, provider: :spotify},
         {:ok, playlist} <- Apis.spotify().create_playlist(scope, playlist) do
      Apis.spotify().add_items_to_playlist(scope, playlist.playlist_id, Enum.take(tracks, 100))
    end
  end

  def find_tracks(%Festival{concerts: concerts}) do
    concerts
    |> Enum.map(&find_track/1)
    |> Enum.reject(fn {_, track} -> is_nil(track) end)
    |> Enum.map(fn {_, track} -> track end)
  end

  def find_track(%Festival.Concert{artist: artist}) do
    with {:ok, id} <- Apis.spotify().search_artist(artist),
         {:ok, track} <- Apis.spotify().get_artist_top_track(id) do
      {:ok, track}
    else
      _ -> {:error, nil}
    end
  end
end
