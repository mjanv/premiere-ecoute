defmodule PremiereEcoute.Discography.Billboard do
  @moduledoc """
  Service for generating music billboards from playlist URLs.

  Processes Spotify and Deezer playlist URLs to create a ranked list of tracks
  based on their frequency across playlists.
  """

  require Logger

  alias PremiereEcoute.Apis

  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track

  def generate_billboard(playlist_urls, opts \\ []) when is_list(playlist_urls) do
    callback = Keyword.get(opts, :callback, fn _, _ -> :ok end)

    try do
      with :ok <- callback.("Starting", 0),
           playlist_ids <- extract_playlist_ids(playlist_urls),
           :ok <- callback.("Fetching playlists", 10),
           playlists <- loop(playlist_ids, callback),
           tracks <- Enum.flat_map(playlists, fn %Playlist{tracks: tracks} -> tracks end),
           :ok <- callback.("Stats", 100),
           track <- group_by(tracks, :track),
           artist <- group_by(tracks, :artist),
           year <- group_by(tracks, :year) do
        {:ok, %{track: track, artist: artist, year: year}}
      end
    rescue
      error ->
        Logger.error("#{inspect(reason)}")
        {:error, Exception.message(error)}
    end
  end

  def loop(playlist_ids, callback) do
    total = length(playlist_ids)

    playlist_ids
    |> Enum.with_index(1)
    |> Enum.map(fn {{provider, playlist_id}, index} ->
      callback.("Fetching playlist #{index}/#{total}", 10 + div(index * 90, total))
      {:ok, %Playlist{tracks: tracks} = playlist} = Apis.provider(provider).get_playlist(playlist_id)
      playlist
    end)
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

  defp group_by(tracks, :track) do
    tracks
    |> Enum.group_by(fn track -> clean_value(track.artist <> " " <> track.name) end)
    |> Enum.map(fn {_key, [track | _] = tracks} ->
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
    |> Enum.group_by(fn track -> clean_value(track.artist) end)
    |> Enum.map(fn {_, [first_track | _] = tracks} ->
      %{
        artist: Map.get(first_track, :artist),
        count: Enum.sum(Enum.map(group_by(tracks, :track), & &1.count)),
        track_count: length(tracks),
        tracks: tracks
      }
    end)
    |> Enum.sort_by(& &1.count, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {row, rank} -> Map.put(row, :rank, rank) end)
  end

  defp group_by(tracks, :year) do
    tracks
    |> Enum.group_by(fn track -> track.release_date.year end)
    |> Enum.map(fn {year, [first_track | _] = tracks} ->
      %{
        year: year,
        count: Enum.sum(Enum.map(group_by(tracks, :track), & &1.count)),
        track_count: length(tracks),
        tracks: tracks
      }
    end)
    |> then(fn years -> Map.put(years, :max_count, Enum.max(Enum.map(years, & &1.count))) end)
    |> Enum.sort_by(& &1.year, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {row, rank} -> Map.put(row, :rank, rank) end)
  end

  def clean_value(value) when is_binary(value) do
    value
    # Remove text enclosed in (), [] or located after -
    |> String.replace(~r/ \(.+\).*| \[.+\].*| -.+/, "")
    |> String.downcase()
    # Unicode Normalization Form Decomposed
    |> :unicode.characters_to_nfd_binary()
    # Remove diacritical marks
    |> String.replace(~r/\p{Mn}/u, "")
    # Remove interrogation & exclamation marks
    |> String.replace(~r/[!?]+$/, "")
    |> String.replace(~r/^[!?]+/, "")
    |> String.replace(~r/ [!?]+/, " ")
    |> String.replace(~r/[!?]+ /, " ")
    |> String.replace(~r/[¿¡*,.'':_\/-]/, "")
    # Remove special characters
    |> String.replace("œ", "oe")
    |> String.replace("$", "s")
    |> String.replace("ø", "o")
    |> String.trim()
  end
end
