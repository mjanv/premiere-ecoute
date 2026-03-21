defmodule PremiereEcoute.Playlists.Automations.Actions.RemoveDuplicates do
  @moduledoc false

  use PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Playlist.Track

  action "remove_duplicates" do
    description("Removes duplicate tracks from a playlist (by Spotify track ID).")

    inputs do
      input(:playlist, :playlist_id, required: true, description: "Playlist to deduplicate")
    end

    outputs do
      output(:removed_count, :integer, description: "Number of duplicate tracks removed")
    end
  end

  @impl true
  def execute(%{"playlist" => playlist_id}, _context, scope) do
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
