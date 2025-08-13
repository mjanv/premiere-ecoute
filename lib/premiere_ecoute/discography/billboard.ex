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
      playlist_ids = unique_urls |> Enum.map(&extract_playlist_id/1) |> Enum.reject(&is_nil/1)

      progress_callback.("Fetching playlists", 20)

      tracks =
        playlist_ids
        |> Enum.with_index()
        |> Enum.flat_map(fn {playlist_id, index} ->
          progress = 20 + div((index + 1) * 60, total_playlists)
          progress_callback.("Fetching playlist #{index + 1}/#{total_playlists}", progress)
          playlist_tracks = fetch_playlist_tracks(playlist_id)
          # Add playlist source info to each track
          Enum.map(playlist_tracks, fn track ->
            Map.put(track, :playlist_source, %{
              provider: elem(playlist_id, 0),
              playlist_id: elem(playlist_id, 1),
              playlist_url:
                case playlist_id do
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
    |> Enum.group_by(fn track -> String.downcase(track.artist <> track.name) end)
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
end
