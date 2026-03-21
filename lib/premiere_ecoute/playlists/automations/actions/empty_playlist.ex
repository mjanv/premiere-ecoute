defmodule PremiereEcoute.Playlists.Automations.Actions.EmptyPlaylist do
  @moduledoc false

  use PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Apis

  action "empty_playlist" do
    description("Removes all tracks from a playlist.")

    inputs do
      input(:playlist, :playlist_id, required: true, description: "Playlist to empty")
    end

    outputs do
      output(:removed_count, :integer, description: "Number of tracks removed")
    end
  end

  @impl true
  def execute(%{"playlist" => playlist_id}, _context, scope) do
    with {:ok, playlist} <- Apis.spotify().get_playlist(playlist_id) do
      case playlist.tracks do
        [] ->
          {:ok, %{removed_count: 0}}

        tracks ->
          with {:ok, _} <- Apis.spotify().remove_playlist_items(scope, playlist_id, tracks) do
            {:ok, %{removed_count: length(tracks)}}
          end
      end
    end
  end
end
