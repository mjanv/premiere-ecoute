defmodule PremiereEcoute.Playlists.Automations.Actions.EmptyPlaylist do
  @moduledoc "Removes all tracks from a playlist."

  @behaviour PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Apis

  @impl true
  def id, do: "empty_playlist"

  @impl true
  def validate_config(%{"playlist_id" => id}) when is_binary(id) and id != "", do: :ok
  def validate_config(_), do: {:error, ["playlist_id is required"]}

  @impl true
  def execute(%{"playlist_id" => playlist_id}, _context, scope) do
    with {:ok, playlist} <- Apis.spotify().get_playlist(playlist_id),
         {:ok, _} <- remove_all(scope, playlist_id, playlist.tracks) do
      {:ok, %{removed_count: length(playlist.tracks)}}
    end
  end

  defp remove_all(_scope, _id, []), do: {:ok, nil}
  defp remove_all(scope, id, tracks), do: Apis.spotify().remove_playlist_items(scope, id, tracks)
end
