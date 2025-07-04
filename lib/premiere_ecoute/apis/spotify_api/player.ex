defmodule PremiereEcoute.Apis.SpotifyApi.Player do
  @moduledoc """
  Spotify Web API Player endpoints for controlling playback.
  """

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi

  @doc """
  Start/resume playback on the user's active device.
  Can optionally specify track URIs to play.
  """
  def start_playback(access_token, opts \\ []) do
    body =
      case opts[:uris] do
        nil -> %{}
        uris when is_list(uris) -> %{uris: uris}
        uri when is_binary(uri) -> %{uris: [uri]}
      end

    # Add position if specified
    body =
      case opts[:position_ms] do
        nil -> body
        pos when is_integer(pos) -> Map.put(body, :position_ms, pos)
      end

    json_body = Jason.encode!(body)
    content_length = byte_size(json_body)

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"},
      {"Content-Length", to_string(content_length)}
    ]

    SpotifyApi.api(:web)
    |> Req.merge(headers: headers)
    |> Req.put(url: "/me/player/play", body: json_body)
    |> handle_playback_response()
  end

  @doc """
  Pause playback on the user's active device.
  """
  def pause_playback(access_token) do
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Length", "0"},
      {"Content-Type", "application/json"}
    ]

    SpotifyApi.api(:web)
    |> Req.merge(headers: headers)
    |> Req.put(url: "/me/player/pause", body: "")
    |> handle_playback_response()
  end

  @doc """
  Skip to next track in the user's queue.
  """
  def next_track(access_token) do
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Length", "0"},
      {"Content-Type", "application/json"}
    ]

    SpotifyApi.api(:web)
    |> Req.merge(headers: headers)
    |> Req.post(url: "/me/player/next", body: "")
    |> handle_playback_response()
  end

  @doc """
  Skip to previous track in the user's queue.
  """
  def previous_track(access_token) do
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Length", "0"},
      {"Content-Type", "application/json"}
    ]

    SpotifyApi.api(:web)
    |> Req.merge(headers: headers)
    |> Req.post(url: "/me/player/previous", body: "")
    |> handle_playback_response()
  end

  @doc """
  Get information about the user's current playback state.
  """
  def get_playback_state(access_token) do
    headers = [{"Authorization", "Bearer #{access_token}"}]

    SpotifyApi.api(:web)
    |> Req.merge(headers: headers)
    |> Req.get(url: "/me/player")
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 204}} ->
        # No active device
        {:ok, %{}}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify get playback state failed: #{status} - #{inspect(body)}")
        {:error, "Spotify playback state failed"}

      {:error, reason} ->
        Logger.error("Spotify get playback state request failed: #{inspect(reason)}")
        {:error, "Network error during playback state"}
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
