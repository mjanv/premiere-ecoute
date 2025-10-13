defmodule PremiereEcoute.Playlists do
  @moduledoc false

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.PlaylistRule
  alias PremiereEcoute.Playlists.Services.PlaylistCreation
  alias PremiereEcoute.Playlists.Services.PlaylistExport

  # Library playlist management
  defdelegate create_library_playlist(scope, playlist), to: PlaylistCreation
  defdelegate export_tracks_to_playlist(scope, playlist_id, tracks), to: PlaylistExport
  defdelegate all_for_user(user), to: LibraryPlaylist

  # Playlist rules management
  defdelegate set_save_tracks_playlist(user, library_playlist), to: PlaylistRule
  defdelegate get_save_tracks_playlist(user), to: PlaylistRule
  defdelegate get_save_tracks_rule(user), to: PlaylistRule
  defdelegate deactivate_save_tracks_playlist(user), to: PlaylistRule
end
