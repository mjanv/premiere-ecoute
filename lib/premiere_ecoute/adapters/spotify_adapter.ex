defmodule PremiereEcoute.Adapters.SpotifyAdapter do
  @moduledoc """
  Spotify API adapter that implements the MusicMetadataPort.
  Converts all Spotify API responses to proper Elixir structs.
  Now includes playback control for streaming sessions.
  """

  @behaviour PremiereEcoute.Core.Ports.MusicMetadataPort

  alias PremiereEcoute.Core.Entities.{Album, Track}
  alias PremiereEcoute.Core.Ports.MusicMetadataPort

  require Logger

  @spotify_api_base "https://api.spotify.com/v1"

  @impl MusicMetadataPort
  def search_albums(query) when is_binary(query) do
    case get_access_token() do
      {:ok, token} ->
        search_url = "#{@spotify_api_base}/search?q=#{URI.encode(query)}&type=album&limit=20"

        case Req.get(search_url, headers: [{"Authorization", "Bearer #{token}"}]) do
          {:ok, %{status: 200, body: body}} ->
            albums = parse_search_results(body)
            {:ok, albums}

          {:ok, %{status: status, body: body}} ->
            Logger.error("Spotify search failed: #{status} - #{inspect(body)}")
            {:error, "Spotify API error: #{status}"}

          {:error, reason} ->
            Logger.error("Spotify request failed: #{inspect(reason)}")
            {:error, "Network error: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl MusicMetadataPort
  def get_album_with_tracks(album_id) when is_binary(album_id) do
    case get_access_token() do
      {:ok, token} ->
        album_url = "#{@spotify_api_base}/albums/#{album_id}"

        case Req.get(album_url, headers: [{"Authorization", "Bearer #{token}"}]) do
          {:ok, %{status: 200, body: body}} ->
            album = parse_album_with_tracks(body)
            {:ok, album}

          {:ok, %{status: status, body: body}} ->
            Logger.error("Spotify album fetch failed: #{status} - #{inspect(body)}")
            {:error, "Spotify API error: #{status}"}

          {:error, reason} ->
            Logger.error("Spotify request failed: #{inspect(reason)}")
            {:error, "Network error: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl MusicMetadataPort
  def get_track_details(track_id) when is_binary(track_id) do
    case get_access_token() do
      {:ok, token} ->
        track_url = "#{@spotify_api_base}/tracks/#{track_id}"

        case Req.get(track_url, headers: [{"Authorization", "Bearer #{token}"}]) do
          {:ok, %{status: 200, body: body}} ->
            track = parse_track(body)
            {:ok, track}

          {:ok, %{status: status, body: body}} ->
            Logger.error("Spotify track fetch failed: #{status} - #{inspect(body)}")
            {:error, "Spotify API error: #{status}"}

          {:error, reason} ->
            Logger.error("Spotify request failed: #{inspect(reason)}")
            {:error, "Network error: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Playback Control Methods

  @doc """
  Start playback of an album on the user's Spotify device
  """
  def start_album_playback(user_token, album_id, device_id \\ nil)
      when is_binary(user_token) and is_binary(album_id) do
    playback_url = "#{@spotify_api_base}/me/player/play"

    playback_url = if device_id, do: "#{playback_url}?device_id=#{device_id}", else: playback_url

    body = %{
      context_uri: "spotify:album:#{album_id}",
      position_ms: 0
    }

    case Req.put(playback_url,
           headers: [
             {"Authorization", "Bearer #{user_token}"},
             {"Content-Type", "application/json"}
           ],
           json: body
         ) do
      {:ok, %{status: status}} when status in [200, 204] ->
        {:ok, :playing}

      {:ok, %{status: 404}} ->
        {:error, "No active Spotify device found"}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify playback failed: #{status} - #{inspect(body)}")
        {:error, "Playback failed: #{status}"}

      {:error, reason} ->
        Logger.error("Spotify playback request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  @doc """
  Start playback of a specific track
  """
  def start_track_playback(user_token, track_id, device_id \\ nil)
      when is_binary(user_token) and is_binary(track_id) do
    playback_url = "#{@spotify_api_base}/me/player/play"

    playback_url = if device_id, do: "#{playback_url}?device_id=#{device_id}", else: playback_url

    body = %{
      uris: ["spotify:track:#{track_id}"],
      position_ms: 0
    }

    case Req.put(playback_url,
           headers: [
             {"Authorization", "Bearer #{user_token}"},
             {"Content-Type", "application/json"}
           ],
           json: body
         ) do
      {:ok, %{status: status}} when status in [200, 204] ->
        {:ok, :playing}

      {:ok, %{status: 404}} ->
        {:error, "No active Spotify device found"}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify track playback failed: #{status} - #{inspect(body)}")
        {:error, "Playback failed: #{status}"}

      {:error, reason} ->
        Logger.error("Spotify track playback request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  @doc """
  Pause Spotify playback
  """
  def pause_playback(user_token, device_id \\ nil) when is_binary(user_token) do
    pause_url = "#{@spotify_api_base}/me/player/pause"

    pause_url = if device_id, do: "#{pause_url}?device_id=#{device_id}", else: pause_url

    case Req.put(pause_url,
           headers: [{"Authorization", "Bearer #{user_token}"}]
         ) do
      {:ok, %{status: status}} when status in [200, 204] ->
        {:ok, :paused}

      {:ok, %{status: 404}} ->
        {:error, "No active Spotify device found"}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify pause failed: #{status} - #{inspect(body)}")
        {:error, "Pause failed: #{status}"}

      {:error, reason} ->
        Logger.error("Spotify pause request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  @doc """
  Resume Spotify playback
  """
  def resume_playback(user_token, device_id \\ nil) when is_binary(user_token) do
    play_url = "#{@spotify_api_base}/me/player/play"

    play_url = if device_id, do: "#{play_url}?device_id=#{device_id}", else: play_url

    case Req.put(play_url,
           headers: [{"Authorization", "Bearer #{user_token}"}]
         ) do
      {:ok, %{status: status}} when status in [200, 204] ->
        {:ok, :playing}

      {:ok, %{status: 404}} ->
        {:error, "No active Spotify device found"}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify resume failed: #{status} - #{inspect(body)}")
        {:error, "Resume failed: #{status}"}

      {:error, reason} ->
        Logger.error("Spotify resume request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  @doc """
  Skip to next track
  """
  def skip_to_next(user_token, device_id \\ nil) when is_binary(user_token) do
    next_url = "#{@spotify_api_base}/me/player/next"

    next_url = if device_id, do: "#{next_url}?device_id=#{device_id}", else: next_url

    case Req.post(next_url,
           headers: [{"Authorization", "Bearer #{user_token}"}]
         ) do
      {:ok, %{status: status}} when status in [200, 204] ->
        {:ok, :skipped}

      {:ok, %{status: 404}} ->
        {:error, "No active Spotify device found"}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify skip failed: #{status} - #{inspect(body)}")
        {:error, "Skip failed: #{status}"}

      {:error, reason} ->
        Logger.error("Spotify skip request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  @doc """
  Skip to previous track
  """
  def skip_to_previous(user_token, device_id \\ nil) when is_binary(user_token) do
    prev_url = "#{@spotify_api_base}/me/player/previous"

    prev_url = if device_id, do: "#{prev_url}?device_id=#{device_id}", else: prev_url

    case Req.post(prev_url,
           headers: [{"Authorization", "Bearer #{user_token}"}]
         ) do
      {:ok, %{status: status}} when status in [200, 204] ->
        {:ok, :skipped}

      {:ok, %{status: 404}} ->
        {:error, "No active Spotify device found"}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify previous failed: #{status} - #{inspect(body)}")
        {:error, "Previous failed: #{status}"}

      {:error, reason} ->
        Logger.error("Spotify previous request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  @doc """
  Get current playback state
  """
  def get_playback_state(user_token) when is_binary(user_token) do
    playback_url = "#{@spotify_api_base}/me/player"

    case Req.get(playback_url,
           headers: [{"Authorization", "Bearer #{user_token}"}]
         ) do
      {:ok, %{status: 200, body: body}} ->
        playback_state = parse_playback_state(body)
        {:ok, playback_state}

      {:ok, %{status: 204}} ->
        {:ok, %{is_playing: false, device: nil, item: nil}}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify playback state failed: #{status} - #{inspect(body)}")
        {:error, "Playback state failed: #{status}"}

      {:error, reason} ->
        Logger.error("Spotify playback state request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  @doc """
  Get available Spotify devices
  """
  def get_available_devices(user_token) when is_binary(user_token) do
    devices_url = "#{@spotify_api_base}/me/player/devices"

    case Req.get(devices_url,
           headers: [{"Authorization", "Bearer #{user_token}"}]
         ) do
      {:ok, %{status: 200, body: %{"devices" => devices}}} ->
        parsed_devices = parse_devices(devices)
        {:ok, parsed_devices}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify devices failed: #{status} - #{inspect(body)}")
        {:error, "Devices fetch failed: #{status}"}

      {:error, reason} ->
        Logger.error("Spotify devices request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  # Private functions for API interaction and data conversion

  defp get_access_token do
    client_id = Application.get_env(:premiere_ecoute, :spotify_client_id)
    client_secret = Application.get_env(:premiere_ecoute, :spotify_client_secret)

    if client_id && client_secret do
      auth_string = Base.encode64("#{client_id}:#{client_secret}")

      case Req.post("https://accounts.spotify.com/api/token",
             headers: [
               {"Authorization", "Basic #{auth_string}"},
               {"Content-Type", "application/x-www-form-urlencoded"}
             ],
             body: "grant_type=client_credentials"
           ) do
        {:ok, %{status: 200, body: %{"access_token" => token}}} ->
          {:ok, token}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Spotify auth failed: #{status} - #{inspect(body)}")
          {:error, "Spotify authentication failed"}

        {:error, reason} ->
          Logger.error("Spotify auth request failed: #{inspect(reason)}")
          {:error, "Network error during authentication"}
      end
    else
      {:error, "Spotify credentials not configured"}
    end
  end

  defp parse_search_results(%{"albums" => %{"items" => items}}) do
    Enum.map(items, fn item ->
      %{
        id: item["id"],
        name: item["name"],
        artist: get_primary_artist(item["artists"]),
        release_date: parse_release_date(item["release_date"]),
        cover_url: get_album_cover_url(item["images"]),
        total_tracks: item["total_tracks"] || 0
      }
    end)
  end

  defp parse_search_results(_), do: []

  defp parse_album_with_tracks(album_data) do
    tracks = parse_tracks(album_data["tracks"]["items"] || [], album_data["id"])

    %Album{
      spotify_id: album_data["id"],
      name: album_data["name"],
      artist: get_primary_artist(album_data["artists"]),
      release_date: parse_release_date(album_data["release_date"]),
      cover_url: get_album_cover_url(album_data["images"]),
      total_tracks: album_data["total_tracks"] || 0,
      tracks: tracks,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp parse_tracks(track_items, album_id) do
    Enum.map(track_items, fn track ->
      %Track{
        spotify_id: track["id"],
        album_id: album_id,
        name: track["name"],
        track_number: track["track_number"] || 0,
        duration_ms: track["duration_ms"] || 0,
        preview_url: track["preview_url"],
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    end)
  end

  defp parse_track(track_data) do
    %Track{
      spotify_id: track_data["id"],
      album_id: track_data["album"]["id"],
      name: track_data["name"],
      track_number: track_data["track_number"] || 0,
      duration_ms: track_data["duration_ms"] || 0,
      preview_url: track_data["preview_url"],
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp parse_playback_state(body) do
    %{
      is_playing: body["is_playing"] || false,
      progress_ms: body["progress_ms"] || 0,
      device: parse_device(body["device"]),
      item: parse_currently_playing_item(body["item"]),
      shuffle_state: body["shuffle_state"] || false,
      repeat_state: body["repeat_state"] || "off"
    }
  end

  defp parse_device(nil), do: nil

  defp parse_device(device) do
    %{
      id: device["id"],
      name: device["name"],
      type: device["type"],
      is_active: device["is_active"] || false,
      volume_percent: device["volume_percent"] || 0
    }
  end

  defp parse_devices(devices) do
    Enum.map(devices, &parse_device/1)
  end

  defp parse_currently_playing_item(nil), do: nil

  defp parse_currently_playing_item(item) do
    %{
      id: item["id"],
      name: item["name"],
      duration_ms: item["duration_ms"] || 0,
      track_number: item["track_number"] || 0,
      album: %{
        id: item["album"]["id"],
        name: item["album"]["name"],
        images: item["album"]["images"] || []
      },
      artists:
        Enum.map(item["artists"] || [], fn artist ->
          %{id: artist["id"], name: artist["name"]}
        end)
    }
  end

  defp get_primary_artist(artists) when is_list(artists) do
    case List.first(artists) do
      %{"name" => name} -> name
      _ -> "Unknown Artist"
    end
  end

  defp get_primary_artist(_), do: "Unknown Artist"

  defp parse_release_date(nil), do: nil
  defp parse_release_date(""), do: nil

  defp parse_release_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        date

      {:error, _} ->
        # Try parsing year-only format
        case Integer.parse(date_string) do
          {year, _} when year > 1900 -> Date.new(year, 1, 1) |> elem(1)
          _ -> nil
        end
    end
  end

  defp get_album_cover_url(images) when is_list(images) do
    # Get the medium-sized image (usually 300x300)
    medium_image =
      Enum.find(images, fn img ->
        (img["height"] || 0) >= 250 && (img["height"] || 0) <= 350
      end)

    case medium_image || List.first(images) do
      %{"url" => url} -> url
      _ -> nil
    end
  end

  defp get_album_cover_url(_), do: nil
end
