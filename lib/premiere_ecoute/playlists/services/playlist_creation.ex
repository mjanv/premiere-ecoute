defmodule PremiereEcoute.Playlists.Services.PlaylistCreation do
  @moduledoc false

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.LibraryPlaylist

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
