defmodule PremiereEcoute.Playlists do
  @moduledoc false

  alias PremiereEcoute.Playlists.Services.PlaylistExport

  defdelegate export_tracks_to_playlist(scope, playlist_id, tracks), to: PlaylistExport
end
