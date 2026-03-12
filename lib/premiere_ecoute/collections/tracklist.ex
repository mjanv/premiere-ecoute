defmodule PremiereEcoute.Collections.Tracklist do
  @moduledoc false

  @cache :collections

  alias PremiereEcoute.Collections.CollectionSession
  alias PremiereEcouteCore.Cache

  def shuffle(%CollectionSession{current_index: idx}, broadcaster_id, tracks) do
    with {:ok, collection} when not is_nil(collection) <- Cache.get(@cache, broadcaster_id),
         {done, remaining} = Enum.split(tracks, idx),
         shuffled = done ++ Enum.shuffle(remaining),
         {:ok, _} <- Cache.put(@cache, broadcaster_id, Map.put(collection, :tracks, shuffled)) do
      {:ok, shuffled}
    else
      _ -> {:ok, tracks}
    end
  end

  def restore(%CollectionSession{current_index: idx}, broadcaster_id, tracks, original_tracks) do
    with {:ok, collection} when not is_nil(collection) <- Cache.get(@cache, broadcaster_id),
         {done, _} = Enum.split(tracks, idx),
         restored = done ++ Enum.drop(original_tracks, idx),
         {:ok, _} <- Cache.put(@cache, broadcaster_id, Map.put(collection, :tracks, restored)) do
      {:ok, restored}
    else
      _ -> {:ok, tracks}
    end
  end

  def move_to_top(%CollectionSession{current_index: current}, idx, broadcaster_id, tracks) do
    with {:ok, collection} when not is_nil(collection) <- Cache.get(@cache, broadcaster_id),
         {before_current, from_current} = Enum.split(tracks, current),
         remaining_idx = idx - current,
         track = Enum.at(from_current, remaining_idx),
         reordered = before_current ++ [track | List.delete_at(from_current, remaining_idx)],
         {:ok, _} <- Cache.put(@cache, broadcaster_id, Map.put(collection, :tracks, reordered)) do
      {:ok, reordered}
    else
      _ -> {:ok, tracks}
    end
  end

  def reorder(%CollectionSession{current_index: current}, idx, delta, broadcaster_id, tracks) do
    with {:ok, collection} when not is_nil(collection) <- Cache.get(@cache, broadcaster_id),
         target = idx + delta,
         true <- idx > current && target >= current && target < length(tracks),
         track = Enum.at(tracks, idx),
         reordered = tracks |> List.delete_at(idx) |> List.insert_at(target, track),
         {:ok, _} <- Cache.put(@cache, broadcaster_id, Map.put(collection, :tracks, reordered)) do
      {:ok, reordered}
    else
      _ -> {:ok, tracks}
    end
  end
end
