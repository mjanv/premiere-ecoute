defmodule PremiereEcoute.Discography.Billboard do
  @moduledoc """
  Service for generating music billboards from playlist URLs.

  Processes Spotify and Deezer playlist URLs to create a ranked list of tracks
  based on their frequency across playlists.
  """

  require Logger

  alias PremiereEcoute.Apis.DeezerApi
  alias PremiereEcoute.Apis.SpotifyApi

  @doc """
  Process a list of playlist URLs and generate a billboard of tracks.

  ## Parameters
    - playlist_urls: List of Spotify/Deezer playlist URLs
    - opts: Options including progress callback

  ## Returns
    - {:ok, tracks} where tracks is a list of %{track: track, count: count} maps
    - {:error, reason} if processing fails
  """
  def generate_billboard(playlist_urls, opts \\ []) when is_list(playlist_urls) do
    progress_callback = Keyword.get(opts, :progress_callback, fn _, _ -> :ok end)

    Logger.info("Processing #{length(playlist_urls)} playlist(s)...")
    progress_callback.("Starting", 0)

    try do
      unique_urls = Enum.uniq(playlist_urls)
      total_playlists = length(unique_urls)

      progress_callback.("Extracting playlist IDs", 10)

      playlist_ids =
        unique_urls
        |> Enum.map(&extract_playlist_id/1)
        |> Enum.reject(&is_nil/1)

      progress_callback.("Fetching playlists", 20)

      tracks =
        playlist_ids
        |> Enum.with_index()
        |> Enum.flat_map(fn {{provider, playlist_id}, index} ->
          progress = 20 + div((index + 1) * 60, total_playlists)
          progress_callback.("Fetching playlist #{index + 1}/#{total_playlists}", progress)

          {provider, playlist_id}
          |> fetch_playlist_tracks()
          |> Enum.map(fn track ->
            Map.put(track, :playlist_source, %{
              provider: provider,
              playlist_id: playlist_id,
              playlist_url:
                case {provider, playlist_id} do
                  {:spotify, id} -> "https://open.spotify.com/playlist/#{id}"
                  {:deezer, id} -> "https://www.deezer.com/playlist/#{id}"
                end
            })
          end)
        end)

      progress_callback.("Processing tracks", 85)

      final_tracks =
        tracks
        |> group_by_track()

      progress_callback.("Complete", 100)
      {:ok, final_tracks}
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  @doc """
  Generate ASCII art header for the billboard display.
  """
  def generate_ascii_header do
    [
      "██████╗ ██╗██╗     ██╗     ██████╗  ██████╗  █████╗ ██████╗ ██████╗ ",
      "██╔══██╗██║██║     ██║     ██╔══██╗██╔═══██╗██╔══██╗██╔══██╗██╔══██╗",
      "██████╔╝██║██║     ██║     ██████╔╝██║   ██║███████║██████╔╝██║  ██║",
      "██╔══██╗██║██║     ██║     ██╔══██╗██║   ██║██╔══██║██╔══██╗██║  ██║",
      "██████╔╝██║███████╗███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝",
      "╚═════╝ ╚═╝╚══════╝╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ "
    ]
  end

  @doc """
  Generate artist billboard from track data.

  Groups tracks by artist and aggregates their frequency counts and track details.
  Returns formatted artist entries suitable for display.
  """
  def generate_artist_billboard(tracks) do
    tracks
    |> group_by_artist()
    |> Enum.with_index(1)
    |> Enum.map(fn {artist_data, rank} ->
      format_artist_entry(artist_data, rank)
    end)
  end

  @doc """
  Generate year billboard from track data.

  Groups tracks by release year and aggregates their frequency counts and track details.
  Returns formatted year entries suitable for display, sorted in reverse chronological order.
  """
  def generate_year_billboard(tracks) do
    tracks
    |> group_by_year()
    |> Enum.with_index(1)
    |> Enum.map(fn {year_data, rank} ->
      format_year_entry(year_data, rank)
    end)
  end

  @doc """
  Format a track entry for display with rank styling.
  """
  def format_track_entry(%{track: track, count: count, playlist_sources: playlist_sources}, rank) do
    {_color, icon} = rank_style(rank)
    rank_text = String.pad_leading("#{icon} #{rank}", 6)
    count_text = "[#{count}x]"

    # Generate streaming service URLs
    spotify_url =
      case track.provider do
        :spotify -> "https://open.spotify.com/track/#{track.track_id}"
        _ -> nil
      end

    deezer_url =
      case track.provider do
        :deezer -> "https://www.deezer.com/track/#{track.track_id}"
        _ -> nil
      end

    %{
      rank: rank,
      rank_text: rank_text,
      rank_icon: icon,
      count: count,
      count_text: count_text,
      artist: track.artist,
      name: track.name,
      count_style_class: count_style_class(count),
      rank_style_class: rank_style_class(rank),
      track_id: track.track_id,
      provider: track.provider,
      spotify_url: spotify_url,
      deezer_url: deezer_url,
      playlist_sources: playlist_sources
    }
  end

  # AIDEV-NOTE: Private functions extracted from Mix.Tasks.Albums for reusability

  defp extract_playlist_id(url) do
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
  end

  defp fetch_playlist_tracks({:spotify, playlist_id}) do
    case SpotifyApi.get_playlist(playlist_id) do
      {:ok, playlist} -> playlist.tracks
      {:error, reason} -> raise "Cannot fetch Spotify playlist #{playlist_id}: #{inspect(reason)}"
    end
  end

  defp fetch_playlist_tracks({:deezer, playlist_id}) do
    case DeezerApi.get_playlist(playlist_id) do
      {:ok, playlist} -> playlist.tracks
      {:error, reason} -> raise "Cannot fetch Deezer playlist #{playlist_id}: #{inspect(reason)}"
    end
  end

  defp group_by_track(tracks) do
    tracks
    |> Enum.group_by(fn track -> clean_value(track.artist <> " " <> track.name) end)
    |> Enum.map(fn {_, track_instances} ->
      [first_track | _] = track_instances
      playlist_sources = Enum.map(track_instances, & &1.playlist_source)

      %{
        track: first_track,
        tracks: track_instances,
        count: length(track_instances),
        playlist_sources: playlist_sources
      }
    end)
    |> Enum.sort_by(& &1.count, :desc)
  end

  defp rank_style(1), do: {"text-yellow-400", "🥇"}
  defp rank_style(2), do: {"text-gray-300", "🥈"}
  defp rank_style(3), do: {"text-orange-400", "🥉"}
  defp rank_style(_), do: {"text-cyan-400", "•"}

  defp rank_style_class(1), do: "text-yellow-400"
  defp rank_style_class(2), do: "text-gray-300"
  defp rank_style_class(3), do: "text-orange-400"
  defp rank_style_class(_), do: "text-cyan-400"

  defp count_style_class(count) when count >= 10, do: "text-red-400"
  defp count_style_class(count) when count >= 5, do: "text-yellow-400"
  defp count_style_class(count) when count >= 2, do: "text-green-400"
  defp count_style_class(_), do: "text-white"

  # AIDEV-NOTE: Artist aggregation and formatting functions
  defp group_by_artist(tracks) do
    tracks
    |> Enum.group_by(fn %{track: track} -> clean_value(track.artist) end)
    |> Enum.map(fn {_artist_key, track_instances} ->
      artist_name = track_instances |> List.first() |> Map.get(:track) |> Map.get(:artist)
      total_count = track_instances |> Enum.map(& &1.count) |> Enum.sum()
      track_count = length(track_instances)

      # Collect all unique tracks for this artist with their details
      artist_tracks =
        Enum.map(track_instances, fn %{track: track, count: count, playlist_sources: sources} ->
          %{
            name: track.name,
            count: count,
            track_id: track.track_id,
            provider: track.provider,
            playlist_sources: sources,
            spotify_url:
              case track.provider do
                :spotify -> "https://open.spotify.com/track/#{track.track_id}"
                _ -> nil
              end,
            deezer_url:
              case track.provider do
                :deezer -> "https://www.deezer.com/track/#{track.track_id}"
                _ -> nil
              end
          }
        end)

      %{
        artist: artist_name,
        total_count: total_count,
        track_count: track_count,
        tracks: artist_tracks
      }
    end)
    |> Enum.sort_by(& &1.total_count, :desc)
  end

  defp format_artist_entry(%{artist: artist, total_count: total_count, track_count: track_count, tracks: tracks}, rank) do
    {_color, icon} = rank_style(rank)
    rank_text = String.pad_leading("#{icon} #{rank}", 6)
    count_text = "[#{total_count}x]"

    %{
      rank: rank,
      rank_text: rank_text,
      rank_icon: icon,
      artist: artist,
      total_count: total_count,
      track_count: track_count,
      count_text: count_text,
      count_style_class: count_style_class(total_count),
      rank_style_class: rank_style_class(rank),
      tracks: tracks
    }
  end

  # AIDEV-NOTE: Year aggregation and formatting functions
  defp group_by_year(tracks) do
    year_data =
      tracks
      |> Enum.filter(fn %{track: track} -> track.release_date != nil end)
      |> Enum.group_by(fn %{track: track} -> track.release_date.year end)
      |> Enum.map(fn {year, track_instances} ->
        total_count = track_instances |> Enum.map(& &1.count) |> Enum.sum()
        track_count = length(track_instances)

        # Collect all unique tracks for this year with their details
        year_tracks =
          Enum.map(track_instances, fn %{track: track, count: count, playlist_sources: sources} ->
            %{
              name: track.name,
              artist: track.artist,
              count: count,
              track_id: track.track_id,
              provider: track.provider,
              playlist_sources: sources,
              spotify_url:
                case track.provider do
                  :spotify -> "https://open.spotify.com/track/#{track.track_id}"
                  _ -> nil
                end,
              deezer_url:
                case track.provider do
                  :deezer -> "https://www.deezer.com/track/#{track.track_id}"
                  _ -> nil
                end
            }
          end)

        %{
          year: year,
          total_count: total_count,
          track_count: track_count,
          tracks: year_tracks
        }
      end)

    # Sort by count for podium ranking (assign ranks to top 3)
    sorted_by_count = Enum.sort_by(year_data, & &1.total_count, :desc)

    # Assign podium ranks to top 3
    year_data_with_ranks =
      year_data
      |> Enum.map(fn year_entry ->
        podium_rank =
          case Enum.find_index(sorted_by_count, fn x -> x.year == year_entry.year end) do
            index when index in [0, 1, 2] -> index + 1
            _ -> nil
          end

        Map.put(year_entry, :podium_rank, podium_rank)
      end)

    # Sort by year in reverse chronological order for display
    Enum.sort_by(year_data_with_ranks, & &1.year, :desc)
  end

  defp format_year_entry(
         %{year: year, total_count: total_count, track_count: track_count, tracks: tracks, podium_rank: podium_rank},
         rank
       ) do
    # Use podium rank for display if this year is in top 3, otherwise use chronological rank
    display_rank = podium_rank || rank
    {_color, icon} = rank_style(display_rank)
    rank_text = String.pad_leading("#{icon} #{display_rank}", 6)
    count_text = "[#{total_count}x]"

    %{
      rank: rank,
      display_rank: display_rank,
      rank_text: rank_text,
      rank_icon: icon,
      year: year,
      total_count: total_count,
      track_count: track_count,
      count_text: count_text,
      count_style_class: count_style_class(total_count),
      rank_style_class: rank_style_class(display_rank),
      tracks: tracks
    }
  end

  def clean_value(value) when is_binary(value) do
    value
    |> String.replace(~r/ \(.+\).*| \[.+\].*| -.+/, "")
    |> String.downcase()
    |> normalize_unicode()
    |> remove_diacritics()
    |> String.replace(~r/[!?]+$/, "")
    |> String.replace(~r/^[!?]+/, "")
    |> String.replace(~r/ [!?]+/, " ")
    |> String.replace(~r/[!?]+ /, " ")
    |> String.replace(~r/[¿¡*,.'':_\/-]/, "")
    |> String.replace("œ", "oe")
    |> String.replace("$", "s")
    |> String.replace("ø", "o")
    |> String.trim()
  end

  # Helper function to normalize Unicode (NFD - Normalization Form Decomposed)
  defp normalize_unicode(string) do
    :unicode.characters_to_nfd_binary(string)
  end

  # Helper function to remove diacritical marks
  defp remove_diacritics(string) do
    String.replace(string, ~r/\p{Mn}/u, "")
  end
end
