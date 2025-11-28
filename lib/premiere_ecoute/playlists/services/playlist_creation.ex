defmodule PremiereEcoute.Playlists.Services.PlaylistCreation do
  @moduledoc """
  Playlist creation service.

  Creates playlists on Spotify and stores them in user's library playlist collection.
  """

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.LibraryPlaylist

  @doc """
  Creates playlist on Spotify and saves to user's library.

  Creates playlist via Spotify API then stores metadata in library playlists table.
  """
  @spec create_library_playlist(PremiereEcoute.Accounts.Scope.t(), LibraryPlaylist.t()) ::
          {:ok, LibraryPlaylist.t()} | {:error, term()}
  def create_library_playlist(scope, %LibraryPlaylist{} = playlist) do
    with {:ok, playlist} <- Apis.spotify().create_playlist(scope, playlist),
         playlist <- Map.take(playlist, [:provider, :playlist_id, :title, :description, :public, :track_count, :url, :metadata]),
         {:ok, playlist} <- LibraryPlaylist.create(scope.user, playlist) do
      {:ok, playlist}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
