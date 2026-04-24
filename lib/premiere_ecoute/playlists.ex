defmodule PremiereEcoute.Playlists do
  @moduledoc """
  Playlists context.

  Manages user playlist libraries including creation and export to music platforms.
  """

  use PremiereEcouteCore.Context

  # TODO: Cross-context ?
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.PlaylistSubmission
  alias PremiereEcoute.Playlists.Services.PlaylistCreation
  alias PremiereEcoute.Playlists.Services.PlaylistExport

  defdelegate create_library_playlist(scope, playlist), to: PlaylistCreation
  defdelegate delete_library_playlist(user, playlist), to: LibraryPlaylist, as: :delete
  defdelegate export_tracks_to_playlist(scope, playlist_id, tracks), to: PlaylistExport
  defdelegate all_for_user(user), to: LibraryPlaylist

  defdelegate create_submission(playlist, user, provider_id), to: PlaylistSubmission, as: :create
  defdelegate count_submissions_for_viewer(playlist, user), to: PlaylistSubmission, as: :count_for_viewer
  defdelegate submitters_map(playlist), to: PlaylistSubmission
  defdelegate delete_stale_submissions(playlist, live_track_ids), to: PlaylistSubmission, as: :delete_stale
end
