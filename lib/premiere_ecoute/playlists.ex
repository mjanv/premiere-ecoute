defmodule PremiereEcoute.Playlists do
  @moduledoc false

  alias PremiereEcoute.Playlists.Services.PlaylistCreation
  alias PremiereEcoute.Playlists.Services.PlaylistExport

  defdelegate create_library_playlist(scope, playlist), to: PlaylistCreation
  defdelegate export_tracks_to_playlist(scope, playlist_id, tracks), to: PlaylistExport
end
