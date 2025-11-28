defmodule PremiereEcoute.Festivals.Services.TrackSearch do
  @moduledoc """
  Festival track search service.

  Searches Spotify for top tracks by festival lineup artists, creates playlists from found tracks, and broadcasts progress via PubSub for real-time updates.
  """

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Festivals.Festival
  alias PremiereEcoute.Festivals.Festival.Concert

  @doc """
  Creates Spotify playlist from festival tracks.

  Creates playlist with festival name containing up to 100 tracks from provided track list.
  """
  @spec create_festival_playlist(PremiereEcoute.Accounts.Scope.t(), Festival.t(), list(map())) :: {:ok, map()} | {:error, term()}
  def create_festival_playlist(scope, %Festival{name: name}, tracks) do
    with playlist <- %LibraryPlaylist{title: name, description: "", public: false, provider: :spotify},
         {:ok, playlist} <- Apis.spotify().create_playlist(scope, playlist) do
      Apis.spotify().add_items_to_playlist(scope, playlist.playlist_id, Enum.take(tracks, 100))
    end
  end

  @doc """
  Searches Spotify for top tracks by festival artists.

  Iterates through festival concerts, finds top track for each artist on Spotify, updates concert with track info, and broadcasts progress.
  """
  @spec find_tracks(PremiereEcoute.Accounts.Scope.t(), Festival.t()) :: Festival.t()
  def find_tracks(scope, %Festival{} = festival) do
    Enum.reduce(festival.concerts, festival, fn concert, festival ->
      artist = concert.artist

      festival =
        update_in(festival.concerts, fn concerts ->
          Enum.map(concerts, fn
            %{artist: ^artist} = c -> %{c | track: find_track(concert)}
            c -> c
          end)
        end)

      PremiereEcoute.PubSub.broadcast("festival:#{scope.user.id}", {:partial, festival})

      festival
    end)
  end

  @doc """
  Finds top Spotify track for concert artist.

  Searches Spotify for artist and retrieves their top track. Returns track info or nil if not found.
  """
  @spec find_track(Concert.t()) :: Concert.Track.t() | nil
  def find_track(%Concert{artist: artist}) do
    with {:ok, %{id: id}} <- Apis.spotify().search_artist(artist),
         {:ok, track} <- Apis.spotify().get_artist_top_track(id) do
      %Concert.Track{provider: "spotify", track_id: track.track_id, name: track.name}
    else
      _ -> nil
    end
  end
end
