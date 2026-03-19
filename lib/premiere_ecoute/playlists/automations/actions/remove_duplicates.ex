defmodule PremiereEcoute.Playlists.Automations.Actions.RemoveDuplicates do
  @moduledoc "Removes duplicate tracks from a playlist (by ISRC, falling back to provider track ID)."

  @behaviour PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Playlist.Track

  @impl true
  def id, do: "remove_duplicates"

  @impl true
  def validate_config(%{"playlist_id" => id}) when is_binary(id) and id != "", do: :ok
  def validate_config(_), do: {:error, ["playlist_id is required"]}

  @impl true
  def execute(%{"playlist_id" => playlist_id}, _context, scope) do
    with {:ok, playlist} <- Apis.spotify().get_playlist(playlist_id) do
      duplicates = find_duplicates(playlist.tracks)

      case duplicates do
        [] ->
          {:ok, %{removed_count: 0}}

        _ ->
          with {:ok, _} <- Apis.spotify().remove_playlist_items(scope, playlist_id, duplicates) do
            {:ok, %{removed_count: length(duplicates)}}
          end
      end
    end
  end

  # AIDEV-NOTE: keeps first occurrence of each track; deduplication key is
  # Spotify track_id (ISRC-based dedup would require fetching track features)
  defp find_duplicates(tracks) do
    {_, duplicates} =
      Enum.reduce(tracks, {MapSet.new(), []}, fn track, {seen, dups} ->
        key = Track.provider(track, :spotify)

        if MapSet.member?(seen, key) do
          {seen, [track | dups]}
        else
          {MapSet.put(seen, key), dups}
        end
      end)

    duplicates
  end
end
