defmodule PremiereEcoute.Playlists.Automations.Actions.ShufflePlaylist do
  @moduledoc "Shuffles all tracks in a playlist by replacing them in a random order."

  @behaviour PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Apis

  @impl true
  def id, do: "shuffle_playlist"

  @impl true
  def validate(%{"playlist_id" => id}) when is_binary(id) and id != "", do: :ok
  def validate(_), do: {:error, ["playlist_id is required"]}

  @impl true
  def execute(%{"playlist_id" => playlist_id}, _context, scope) do
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
