defmodule PremiereEcoute.Playlists.Automations.Actions.MergePlaylists do
  @moduledoc """
  `target` accepts a literal Spotify ID or `"$created_playlist_id"` to reference
  the playlist created by a preceding `create_playlist` step.
  """

  use PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Playlist.Track

  action "merge_playlists" do
    description("Merges tracks from multiple source playlists into a target, deduplicating by track ID.")

    inputs do
      input(:sources, :playlist_id_list, required: true, description: "Playlists to merge (at least 2)")
      input(:target, :playlist_id, required: true, description: "Playlist to merge into (or $created_playlist_id)")
    end

    outputs do
      output(:merged_count, :integer, description: "Number of unique tracks added to the target")
    end
  end

  # AIDEV-NOTE: overrides generated validate/1 to enforce the minimum-2 list constraint
  @impl true
  def validate(%{"sources" => ids, "target" => tgt})
      when is_list(ids) and length(ids) >= 2 and is_binary(tgt) and tgt != "",
      do: :ok

  def validate(%{"sources" => ids}) when is_list(ids) and length(ids) < 2,
    do: {:error, ["sources must contain at least 2 playlist IDs"]}

  def validate(_), do: {:error, ["sources (list) and target are required"]}

  @impl true
  def execute(%{"sources" => source_ids, "target" => target_id_or_ref}, context, scope) do
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
