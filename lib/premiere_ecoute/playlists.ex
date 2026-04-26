defmodule PremiereEcoute.Playlists do
  @moduledoc """
  Playlists context.

  Manages user playlist libraries including creation and export to music platforms.
  """

  use PremiereEcouteCore.Context

  # TODO: Cross-context ?
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.LibraryPlaylist.Submission
  alias PremiereEcoute.Playlists.Services.PlaylistCreation
  alias PremiereEcoute.Playlists.Services.PlaylistExport

  defdelegate create_library_playlist(scope, playlist), to: PlaylistCreation
  defdelegate delete_library_playlist(user, playlist), to: LibraryPlaylist, as: :delete
  defdelegate export_tracks_to_playlist(scope, playlist_id, tracks), to: PlaylistExport
  defdelegate all_for_user(user), to: LibraryPlaylist

  defdelegate create_submission(playlist, user, provider_id), to: Submission, as: :create
  defdelegate count_submissions_for_viewer(playlist, user), to: Submission, as: :count_for_viewer
  defdelegate list_submissions_for_viewer(playlist, user), to: Submission, as: :list_for_viewer
  defdelegate delete_submission_for_viewer(playlist, user, provider_id), to: Submission, as: :delete_for_viewer
  defdelegate submitters_map(playlist), to: Submission
  defdelegate delete_stale_submissions(playlist, live_track_ids), to: Submission, as: :delete_stale
end
