defmodule PremiereEcoute.Billboards.Services.BillboardCreation do
  @moduledoc """
  Service for generating music billboards from playlist URLs.

  Processes Spotify and Deezer playlist URLs to create a ranked list of tracks
  based on their frequency across playlists.
  """

  require Logger

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcouteCore.Utils

  def generate_billboard(playlist_urls, opts \\ []) when is_list(playlist_urls) do
    callback = Keyword.get(opts, :callback, fn _, _ -> :ok end)

    try do
      with _ <- callback.("Starting", 0),
           playlist_ids <- extract_playlist_ids(playlist_urls),
           _ <- callback.("Fetching playlists", 10),
           playlists <- loop(playlist_ids, callback),
           tracks <- Enum.flat_map(playlists, fn %Playlist{tracks: tracks} -> tracks end),
           _ <- callback.("Compute billboard by track", 85),
           track <- group_by(tracks, :track),
           _ <- callback.("Compute billboard by artist", 90),
           artist <- group_by(tracks, :artist),
           _ <- callback.("Compute billboard by year", 95),
           year <- group_by(tracks, :year),
           year_podium <- group_by(tracks, :year_podium),
           _ <- callback.("Done", 100) do
        {:ok, %{playlists: playlists, track: track, artist: artist, year: year, year_podium: year_podium}}
      end
    rescue
      error ->
        Logger.error("#{inspect(error)}")
        {:error, Exception.message(error)}
    end
  end

  def extract_playlist_ids(urls) do
    urls
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn url ->
      cond do
        match = Regex.run(~r/https:\/\/open\.spotify\.com\/playlist\/([a-zA-Z0-9]+)(?:\?.*)?/, url) ->
          [_, playlist_id] = match
          {:spotify, playlist_id}

        match = Regex.run(~r/https:\/\/www\.deezer\.com\/[a-z]+\/playlist\/([0-9]+)(?:\?.*)?/, url) ->
          [_, playlist_id] = match
          {:deezer, playlist_id}

        true ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp loop(playlist_ids, callback) do
    total = length(playlist_ids)

    playlist_ids
    |> Enum.with_index(1)
    |> Enum.map(fn {{provider, playlist_id}, index} ->
      callback.("Fetching playlist #{index}/#{total}", 10 + div(index * 75, total))
      {:ok, %Playlist{} = playlist} = Apis.provider(provider).get_playlist(playlist_id)
      playlist
    end)
  end

  defp group_by(tracks, :track) do
    tracks
    |> Enum.group_by(fn track -> Utils.sanitize_track(track.artist <> " " <> track.name) end)
    |> Enum.map(fn {_, [track | _] = tracks} ->
      %{
        track: track,
        count: length(tracks),
        tracks: tracks
      }
    end)
    |> Enum.sort_by(& &1.count, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {row, rank} -> Map.put(row, :rank, rank) end)
  end

  defp group_by(tracks, :artist) do
    tracks
    |> Enum.group_by(fn track -> Utils.sanitize_track(track.artist) end)
    |> Enum.map(fn {_, [track | _] = tracks} ->
      %{
        artist: Map.get(track, :artist),
        count: Enum.sum(Enum.map(group_by(tracks, :track), & &1.count)),
        track_count: length(tracks),
        tracks: group_by(tracks, :track)
      }
    end)
    |> Enum.sort_by(& &1.count, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {row, rank} -> Map.put(row, :rank, rank) end)
  end

  defp group_by(tracks, :year) do
    tracks
    |> Enum.group_by(fn track -> track.release_date.year end)
    |> Enum.map(fn {year, tracks} ->
      %{
        year: year,
        count: Enum.sum(Enum.map(group_by(tracks, :track), & &1.count)),
        track_count: length(tracks),
        tracks: group_by(tracks, :track)
      }
    end)
    |> then(fn years ->
      max_count = Enum.max(Enum.map(years, & &1.count))
      Enum.map(years, fn year -> Map.put(year, :max_count, max_count) end)
    end)
    |> Enum.sort_by(& &1.year, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {row, rank} -> Map.put(row, :rank, rank) end)
  end

  defp group_by(tracks, :year_podium) do
    tracks
    |> Enum.group_by(fn track -> track.release_date.year end)
    |> Enum.map(fn {year, tracks} ->
      %{
        year: year,
        count: Enum.sum(Enum.map(group_by(tracks, :track), & &1.count)),
        track_count: length(tracks),
        tracks: group_by(tracks, :track)
      }
    end)
    |> then(fn years ->
      max_count = Enum.max(Enum.map(years, & &1.count))
      Enum.map(years, fn year -> Map.put(year, :max_count, max_count) end)
    end)
    |> Enum.sort_by(& &1.count, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {row, rank} -> Map.put(row, :rank, rank) end)
  end
end
