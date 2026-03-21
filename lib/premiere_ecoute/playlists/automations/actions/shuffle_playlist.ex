defmodule PremiereEcoute.Playlists.Automations.Actions.ShufflePlaylist do
  use PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Apis

  action "shuffle_playlist" do
    description("Shuffles all tracks in a playlist by replacing them in a random order.")

    inputs do
      input(:playlist, :playlist_id, required: true, description: "Playlist to shuffle")
    end

    outputs do
      output(:track_count, :integer, description: "Number of tracks shuffled")
    end
  end

  @impl true
  def execute(%{"playlist" => playlist_id}, _context, scope) do
    with {:ok, playlist} <- Apis.spotify().get_playlist(playlist_id) do
      case playlist.tracks do
        [] ->
          {:ok, %{track_count: 0}}

        tracks ->
          shuffled = Enum.shuffle(tracks)

          with {:ok, _} <- Apis.spotify().replace_items_to_playlist(scope, playlist_id, shuffled) do
            {:ok, %{track_count: length(shuffled)}}
          end
      end
    end
  end
end
