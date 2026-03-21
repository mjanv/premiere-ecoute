defmodule PremiereEcoute.Playlists.Automations.Actions.MergePlaylists do
  @moduledoc """
  Merges tracks from multiple source playlists into a target playlist.

  Fetches all source playlists, deduplicates tracks by Spotify track ID (keeping
  the first occurrence), then appends unique tracks to the target.

  The `target_playlist_id` field accepts either a literal Spotify playlist ID or
  `"$created_playlist_id"` to reference the playlist created by a preceding
  `create_playlist` step via the pipeline context.
  """

  @behaviour PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Playlist.Track

  @impl true
  def id, do: "merge_playlists"

  @impl true
  def validate(%{"source_playlist_ids" => ids, "target_playlist_id" => tgt})
      when is_list(ids) and length(ids) >= 2 and is_binary(tgt) and tgt != "",
      do: :ok

  def validate(%{"source_playlist_ids" => ids}) when is_list(ids) and length(ids) < 2,
    do: {:error, ["source_playlist_ids must contain at least 2 playlist IDs"]}

  def validate(_), do: {:error, ["source_playlist_ids (list) and target_playlist_id are required"]}

  @impl true
  def execute(%{"source_playlist_ids" => source_ids, "target_playlist_id" => target_id_or_ref}, context, scope) do
    target_id = resolve_id(target_id_or_ref, context)

    # AIDEV-NOTE: fetch all sources, halt on first error
    case fetch_all(source_ids) do
      {:ok, all_tracks} ->
        unique_tracks = deduplicate(all_tracks)

        with {:ok, _} <- Apis.spotify().add_items_to_playlist(scope, target_id, unique_tracks) do
          {:ok, %{merged_count: length(unique_tracks)}}
        end

      {:error, _} = err ->
        err
    end
  end

  defp fetch_all(source_ids) do
    Enum.reduce_while(source_ids, {:ok, []}, fn id, {:ok, acc} ->
      case Apis.spotify().get_playlist(id) do
        {:ok, playlist} -> {:cont, {:ok, acc ++ playlist.tracks}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp deduplicate(tracks) do
    {unique, _seen} =
      Enum.reduce(tracks, {[], MapSet.new()}, fn track, {acc, seen} ->
        key = Track.provider(track, :spotify)

        if MapSet.member?(seen, key) do
          {acc, seen}
        else
          {acc ++ [track], MapSet.put(seen, key)}
        end
      end)

    unique
  end

  defp resolve_id("$created_playlist_id", %{"created_playlist_id" => id}), do: id
  defp resolve_id(literal, _context), do: literal
end
