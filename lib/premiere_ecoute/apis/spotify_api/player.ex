defmodule PremiereEcoute.Apis.SpotifyApi.Player do
  @moduledoc """
  Spotify Web API Player endpoints for controlling playback.
  """

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track

  @doc """
  Start/resume playback on the user's active device.
  Can optionally specify track URIs to play.
  """
  def start_playback(%Scope{} = scope) do
    scope
    |> SpotifyApi.api()
    |> Req.merge(
      headers: [
        {"Content-Type", "application/json"},
        {"Content-Length", to_string(byte_size(Jason.encode!(%{})))}
      ]
    )
    |> Req.put(url: "/me/player/play", body: %{})
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
    |> Req.put(url: "/me/player/pause", body: "")
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
    |> Req.post(url: "/me/player/next", body: "")
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
    |> Req.post(url: "/me/player/previous", body: "")
    |> handle_playback_response()
  end

  @doc """
  Get information about the user's current playback state.
  """
  def get_playback_state(%Scope{} = scope) do
    scope
    |> SpotifyApi.api()
    |> Req.get(url: "/me/player")
    |> case do
      {:ok,
       %{
         status: 200,
         body: %{
           "device" => device,
           "is_playing" => is_playing,
           "item" => item,
           "progress_ms" => progress_ms
         }
       }} ->
        state = %{
          "is_playing" => is_playing,
          "item" =>
            item
            |> Map.take(["id", "name", "track_number", "duration_ms"])
            |> Map.merge(%{"progress_ms" => progress_ms}),
          "device" => Map.take(device, ["id", "name", "is_active"])
        }

        {:ok, state}

      {:ok, %{status: 204}} ->
        {:ok, default()}

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
