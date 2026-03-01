defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.Player do
  @moduledoc """
  Spotify Web API Player endpoints for controlling playback.
  """

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track, as: PlaylistTrack
  alias PremiereEcoute.Discography.Single

  def test, do: 67

  @doc """
  Retrieves available Spotify playback devices for the user.

  Returns list of devices where Spotify can play audio including computers, phones, speakers, and TVs.
  """
  @spec devices(Scope.t()) :: {:ok, list(map())} | {:error, list()}
  def devices(%Scope{} = scope) do
    scope
    |> SpotifyApi.api()
    |> Req.merge(headers: [{"Content-Type", "application/json"}])
    |> Req.get(url: "/me/player/devices")
    |> case do
      {:ok, %{status: 200, body: %{"devices" => devices}}} -> {:ok, devices}
      _ -> {:error, []}
    end
  end

  @doc """
  Starts playback on user's active device.

  Accepts album, playlist, or nil to resume current playback. Playback starts from beginning of context.
  """
  @spec start_playback(Scope.t(), Album.t() | Playlist.t() | nil) :: {:ok, :success} | {:error, String.t()}
  def start_playback(%Scope{} = scope, %Album{album_id: id}) do
    scope
    |> SpotifyApi.api()
    |> Req.merge(
      headers: [
        {"Content-Type", "application/json"}
      ]
    )
    |> Req.put(
      url: "/me/player/play",
      json: %{
        "context_uri" => "spotify:album:#{id}",
        "offset" => %{"position" => 0},
        "position_ms" => 0
      }
    )
    |> handle_playback_response()
  end

  def start_playback(%Scope{} = scope, %Playlist{playlist_id: id}) do
    scope
    |> SpotifyApi.api()
    |> Req.merge(
      headers: [
        {"Content-Type", "application/json"}
      ]
    )
    |> Req.put(
      url: "/me/player/play",
      json: %{
        "context_uri" => "spotify:playlist:#{id}",
        "offset" => %{"position" => 0},
        "position_ms" => 0
      }
    )
    |> handle_playback_response()
  end

  def start_playback(%Scope{} = scope, nil) do
    scope
    |> SpotifyApi.api()
    |> Req.merge(
      headers: [
        {"Content-Length", "0"},
        {"Content-Type", "application/json"}
      ]
    )
    |> Req.put(url: "/me/player/play", json: %{})
    |> handle_playback_response()
  end

  @doc """
  Pauses playback on user's active device.

  Stops playback at current position. Playback can be resumed with start_playback.
  """
  @spec pause_playback(Scope.t()) :: {:ok, :success} | {:error, String.t()}
  def pause_playback(%Scope{} = scope) do
    scope
    |> SpotifyApi.api()
    |> Req.merge(
      headers: [
        {"Content-Length", "0"},
        {"Content-Type", "application/json"}
      ]
    )
    |> Req.put(url: "/me/player/pause", json: %{})
    |> handle_playback_response()
  end

  @doc """
  Skips to next track in user's queue.

  Advances playback to the next track in the current context or queue.
  """
  @spec next_track(Scope.t()) :: {:ok, :success} | {:error, String.t()}
  def next_track(%Scope{} = scope) do
    scope
    |> SpotifyApi.api()
    |> Req.merge(
      headers: [
        {"Content-Length", "0"},
        {"Content-Type", "application/json"}
      ]
    )
    |> Req.post(url: "/me/player/next", json: %{})
    |> handle_playback_response()
  end

  @doc """
  Skips to previous track in user's queue.

  Returns to the previous track in the current context. Restarts current track if already playing beyond threshold.
  """
  @spec previous_track(Scope.t()) :: {:ok, :success} | {:error, String.t()}
  def previous_track(%Scope{} = scope) do
    scope
    |> SpotifyApi.api()
    |> Req.merge(
      headers: [
        {"Content-Length", "0"},
        {"Content-Type", "application/json"}
      ]
    )
    |> Req.post(url: "/me/player/previous", json: %{})
    |> handle_playback_response()
  end

  @doc """
  Sets repeat mode on user's active device.

  Accepts :track (repeat current track), :context (repeat album/playlist), or :off (no repeat).
  """
  @spec set_repeat_mode(Scope.t(), :track | :context | :off) :: {:ok, :success} | {:error, String.t()}
  def set_repeat_mode(%Scope{} = scope, state) when state in [:track, :context, :off] do
    scope
    |> SpotifyApi.api()
    |> Req.merge(
      headers: [
        {"Content-Length", "0"},
        {"Content-Type", "application/json"}
      ]
    )
    |> Req.put(url: "/me/player/repeat", params: %{state: Atom.to_string(state)})
    |> handle_playback_response()
  end

  @doc """
  Toggles shuffle mode on user's active device.

  Enables or disables random playback order for the current context.
  """
  @spec toggle_playback_shuffle(Scope.t(), boolean()) :: {:ok, :success} | {:error, String.t()}
  def toggle_playback_shuffle(%Scope{} = scope, state) when is_boolean(state) do
    scope
    |> SpotifyApi.api()
    |> Req.merge(
      headers: [
        {"Content-Length", "0"},
        {"Content-Type", "application/json"}
      ]
    )
    |> Req.put(url: "/me/player/shuffle", params: %{state: to_string(state)})
    |> handle_playback_response()
  end

  @doc """
  Retrieves user's current playback state.

  Returns playback information including playing status, current track, device, and position. Falls back to provided state or default on errors.
  """
  @spec get_playback_state(Scope.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def get_playback_state(%Scope{} = scope, state) do
    scope
    |> SpotifyApi.api()
    |> SpotifyApi.circuit_breaker()
    |> Req.merge(url: "/me/player", retry: false)
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 204}} ->
        {:ok, default()}

      {:ok, %{status: 400}} ->
        {:ok, state}

      {:ok, %{status: 429, body: body}} ->
        Logger.error("Spotify rate limit exceeded: #{inspect(body)}")
        {:error, "Spotify rate limit exceeded"}

      {:ok, %{status: 502, body: body}} ->
        Logger.warning("Spotify get playback state failed with status 502: #{inspect(body)}")
        {:ok, state}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify get playback state failed with status #{status}: #{inspect(body)}")
        {:error, "Spotify playback state failed"}

      {:error, reason} ->
        Logger.error("Spotify get playback state request failed: #{inspect(reason)}")
        {:error, "Network error during playback state"}
    end
  end

  @doc "Returns default playback state when no active playback exists"
  @spec default :: map()
  def default, do: %{"is_playing" => false, "item" => nil, "device" => nil}

  @doc """
  Starts or resumes playback of album, track, or playlist.

  Begins playback from the start of the context. Returns Spotify URI of the played content.
  """
  @spec start_resume_playback(Scope.t(), Album.t() | Track.t() | Playlist.t()) :: {:ok, String.t()} | {:error, term()}
  def start_resume_playback(%Scope{} = scope, %Album{provider: :spotify, album_id: album_id}) do
    scope
    |> SpotifyApi.api()
    |> Req.put(
      url: "/me/player/play",
      json: %{context_uri: "spotify:album:#{album_id}", offset: %{position: 0}, position_ms: 0}
    )
    |> SpotifyApi.handle(204, fn _ -> "spotify:album:#{album_id}" end)
  end

  def start_resume_playback(%Scope{} = scope, %Track{provider: :spotify, track_id: track_id}) do
    scope
    |> SpotifyApi.api()
    |> Req.put(
      url: "/me/player/play",
      json: %{uris: ["spotify:track:#{track_id}"], position_ms: 0}
    )
    |> SpotifyApi.handle(204, fn _ -> "spotify:track:#{track_id}" end)
  end

  def start_resume_playback(%Scope{} = scope, %Single{provider: :spotify, track_id: track_id}) do
    scope
    |> SpotifyApi.api()
    |> Req.put(
      url: "/me/player/play",
      json: %{uris: ["spotify:track:#{track_id}"], position_ms: 0}
    )
    |> SpotifyApi.handle(204, fn _ -> "spotify:track:#{track_id}" end)
  end

  def start_resume_playback(%Scope{} = scope, %PlaylistTrack{provider: :spotify, track_id: track_id}) do
    scope
    |> SpotifyApi.api()
    |> Req.put(
      url: "/me/player/play",
      json: %{uris: ["spotify:track:#{track_id}"], position_ms: 0}
    )
    |> SpotifyApi.handle(204, fn _ -> "spotify:track:#{track_id}" end)
  end

  def start_resume_playback(%Scope{} = scope, %Playlist{playlist_id: playlist_id}) do
    scope
    |> SpotifyApi.api()
    |> Req.put(
      url: "/me/player/play",
      json: %{context_uri: "spotify:playlist:#{playlist_id}", offset: %{position: 0}, position_ms: 0}
    )
    |> SpotifyApi.handle(204, fn _ -> "spotify:playlist:#{playlist_id}" end)
  end

  @doc """
  Adds track or album to user's playback queue.

  Enqueues track immediately or all album tracks sequentially. Items play after current track or context finishes.
  """
  @spec add_item_to_playback_queue(Scope.t(), Track.t() | Album.t()) ::
          {:ok, String.t() | list(String.t())} | {:error, String.t()}
  def add_item_to_playback_queue(%Scope{} = scope, %Track{provider: :spotify, track_id: track_id}) do
    scope
    |> SpotifyApi.api()
    |> Req.merge(
      headers: [
        {"Content-Type", "application/json"},
        {"Content-Length", "0"}
      ]
    )
    |> SpotifyApi.post(
      url: "/me/player/queue",
      params: %{uri: "spotify:track:#{track_id}"}
    )
    |> SpotifyApi.handle(204, fn _ -> "spotify:track:#{track_id}" end)
  end

  def add_item_to_playback_queue(%Scope{} = scope, %Album{tracks: tracks}) do
    results = Enum.map(tracks, fn t -> add_item_to_playback_queue(scope, t) end)

    case Enum.all?(results, fn {status, _} -> status == :ok end) do
      true -> {:ok, Enum.map(results, fn {_, context_uri} -> context_uri end)}
      false -> {:error, "Cannot queue all album tracks"}
    end
  end

  defp handle_playback_response(response) do
    case response do
      {:ok, %{status: status}} when status in [200, 202, 204] ->
        {:ok, :success}

      {:ok, %{status: 404, body: %{"error" => %{"reason" => "NO_ACTIVE_DEVICE"}}}} ->
        {:error, "No active Spotify device found. Please open Spotify on a device first."}

      {:ok, %{status: 403, body: %{"error" => %{"reason" => "PREMIUM_REQUIRED"}}}} ->
        {:error, "Spotify Premium is required for playback control."}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify playback failed: #{status} - #{inspect(body)}")
        {:error, "Spotify playback failed"}

      {:error, reason} ->
        Logger.error("Spotify playback request failed: #{inspect(reason)}")
        {:error, "Network error during playback"}
    end
  end
end
