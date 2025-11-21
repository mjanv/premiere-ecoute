defmodule PremiereEcoute.Apis.SpotifyApi.Player do
  @moduledoc """
  Spotify Web API Player endpoints for controlling playback.
  """

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Playlist

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
  Start/resume playback on the user's active device.
  Can optionally specify track URIs to play.
  """
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
  Pause playback on the user's active device.
  """
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
  Skip to next track in the user's queue.
  """
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
  Skip to previous track in the user's queue.
  """
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
  Set repeat mode (:track, :context, or :off) on the user's active device.
  """
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
  Toggle shuffle mode (false or true) on the user's active device.
  """
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
  Get information about the user's current playback state.
  """
  def get_playback_state(%Scope{} = scope, state) do
    scope
    |> SpotifyApi.api()
    |> Req.merge(url: "/me/player", retry: false)
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 204}} ->
        {:ok, default()}

      {:ok, %{status: 400}} ->
        {:ok, state}

      {:ok, %{status: 429}} ->
        {:error, "Spotify rate limit exceeded"}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify get playback state failed: #{status} - #{inspect(body)}")
        {:error, "Spotify playback state failed"}

      {:error, reason} ->
        Logger.error("Spotify get playback state request failed: #{inspect(reason)}")
        {:error, "Network error during playback state"}
    end
  end

  def default, do: %{"is_playing" => false, "item" => nil, "device" => nil}

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

  def start_resume_playback(%Scope{} = scope, %Playlist{playlist_id: playlist_id}) do
    scope
    |> SpotifyApi.api()
    |> Req.put(
      url: "/me/player/play",
      json: %{context_uri: "spotify:playlist:#{playlist_id}", offset: %{position: 0}, position_ms: 0}
    )
    |> SpotifyApi.handle(204, fn _ -> "spotify:playlist:#{playlist_id}" end)
  end

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
