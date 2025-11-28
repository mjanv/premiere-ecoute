defmodule PremiereEcoute.Discography.Playlist.Similarity do
  @moduledoc """
  Module for calculating similarity between playlists based on track overlap.

  Uses Jaccard similarity coefficient to determine how similar two playlists are
  by comparing their normalized track collections.
  """

  alias PremiereEcouteCore.Utils

  @doc """
  Calculate the Jaccard similarity coefficient between two playlists.

  Returns a percentage (0-100) representing how similar the playlists are
  based on their track overlap.
  """
  @spec calculate_similarity(map(), map()) :: integer()
  def calculate_similarity(playlist1, playlist2) do
    tracks1 = normalize_playlist_tracks(playlist1.tracks)
    tracks2 = normalize_playlist_tracks(playlist2.tracks)

    intersection = MapSet.intersection(tracks1, tracks2) |> MapSet.size()
    union = MapSet.union(tracks1, tracks2) |> MapSet.size()

    if union > 0 do
      round(intersection / union * 100)
    else
      0
    end
  end

  defp normalize_playlist_tracks(tracks) do
    tracks
    |> Enum.map(fn track -> Utils.sanitize_track(track.artist <> " " <> track.name) end)
    |> MapSet.new()
  end

  @doc """
  Find the top N most similar playlists to a target playlist.

  Returns a list of playlists with similarity scores, sorted by similarity descending.
  """
  @spec find_most_similar(map(), [map()], integer()) :: [map()]
  def find_most_similar(target_playlist, all_playlists, n \\ 3) do
    all_playlists
    |> Enum.reject(&(&1.playlist_id == target_playlist.playlist_id))
    |> Enum.map(fn playlist ->
      playlist
      |> Map.put(:similarity_score, calculate_similarity(target_playlist, playlist))
      |> Map.put(:mean_year, calculate_mean_year(playlist.tracks))
    end)
    |> Enum.sort_by(& &1.similarity_score, :desc)
    |> Enum.take(n)
  end

  @doc """
  Calculate the mean release year for a list of tracks.
  """
  @spec calculate_mean_year([map()]) :: integer() | nil
  def calculate_mean_year(tracks) when is_list(tracks) do
    if length(tracks) > 0 do
      total_years = tracks |> Enum.map(& &1.release_date.year) |> Enum.sum()
      round(total_years / length(tracks))
    else
      nil
    end
  end
end
