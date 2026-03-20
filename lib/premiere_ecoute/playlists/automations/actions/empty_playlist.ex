defmodule PremiereEcoute.Playlists.Automations.Actions.EmptyPlaylist do
  @moduledoc "Removes all tracks from a playlist."

  @behaviour PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Apis

  @impl true
  def id, do: "empty_playlist"

  @impl true
  def validate(%{"playlist_id" => id}) when is_binary(id) and id != "", do: :ok
  def validate(_), do: {:error, ["playlist_id is required"]}

  @impl true
  def execute(%{"playlist_id" => playlist_id}, _context, scope) do
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
