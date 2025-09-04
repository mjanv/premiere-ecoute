defmodule PremiereEcoute.Playlists do
  @moduledoc false

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.Services.PlaylistCreation
  alias PremiereEcoute.Playlists.Services.PlaylistExport

  defdelegate create_library_playlist(scope, playlist), to: PlaylistCreation
  defdelegate export_tracks_to_playlist(scope, playlist_id, tracks), to: PlaylistExport
  defdelegate all_for_user(user), to: LibraryPlaylist
end
