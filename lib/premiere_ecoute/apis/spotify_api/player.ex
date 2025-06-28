defmodule PremiereEcoute.Apis.SpotifyApi.Player do
  @moduledoc false

  require Logger

  @doc """
  Start playback of an album on the user's Spotify device
  """
  def start_album_playback(user_token, album_id, device_id \\ nil)
      when is_binary(user_token) and is_binary(album_id) do
    playback_url = "#{@api}/me/player/play"

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
    playback_url = "#{@api}/me/player/play"

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
    pause_url = "#{@api}/me/player/pause"

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
    play_url = "#{@api}/me/player/play"

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
    next_url = "#{@api}/me/player/next"

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
    prev_url = "#{@api}/me/player/previous"

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
    playback_url = "https://api.spotify.com/v1/me/player"

    playback_url
    |> Req.get(headers: [{"Authorization", "Bearer #{user_token}"}])
    |> case do
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
    devices_url = "#{@api}/me/player/devices"

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

  def parse_playback_state(body) do
    %{
      is_playing: body["is_playing"] || false,
      progress_ms: body["progress_ms"] || 0,
      device: parse_device(body["device"]),
      item: parse_currently_playing_item(body["item"]),
      shuffle_state: body["shuffle_state"] || false,
      repeat_state: body["repeat_state"] || "off"
    }
  end

  def parse_device(nil), do: nil

  def parse_device(device) do
    %{
      id: device["id"],
      name: device["name"],
      type: device["type"],
      is_active: device["is_active"] || false,
      volume_percent: device["volume_percent"] || 0
    }
  end

  def parse_devices(devices) do
    Enum.map(devices, &parse_device/1)
  end

  def parse_currently_playing_item(nil), do: nil

  def parse_currently_playing_item(item) do
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
end
