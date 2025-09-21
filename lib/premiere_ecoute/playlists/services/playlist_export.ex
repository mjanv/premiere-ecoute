defmodule PremiereEcoute.Playlists.Services.PlaylistExport do
  @moduledoc false

  alias PremiereEcoute.Apis

  def export_tracks_to_playlist(scope, playlist_id, tracks) do
    with {:ok, playlist} <- Apis.spotify().get_playlist(playlist_id),
         {:ok, _} <- remove_all_playlist_tracks(scope, playlist_id, playlist),
         {:ok, result} <- Apis.spotify().add_items_to_playlist(scope, playlist_id, Enum.take(tracks, 100)) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, "Failed to export tracks: #{inspect(error)}"}
    end
  end

  defp remove_all_playlist_tracks(_scope, _playlist_id, playlist) when is_nil(playlist.tracks) or playlist.tracks == [] do
    {:ok, nil}
  end

  defp remove_all_playlist_tracks(scope, playlist_id, _playlist) do
    case Apis.spotify().get_playlist(playlist_id) do
      {:ok, current_playlist} ->
        tracks_to_remove = current_playlist.tracks || []

        if length(tracks_to_remove) > 0 do
          Apis.spotify().remove_playlist_items(scope, playlist_id, tracks_to_remove)
        else
          {:ok, nil}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
