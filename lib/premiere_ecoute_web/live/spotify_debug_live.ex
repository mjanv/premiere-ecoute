defmodule PremiereEcouteWeb.SpotifyDebugLive do
  @moduledoc """
  Spotify player debug page.

  Spins up the real Spotify player endpoints for the current user (not the
  test mock) and surfaces as much raw information as possible: full
  `/me/player` payload, `/me/player/devices`, and the exact status/body of
  every player command, so intermittent Spotify-side failures (e.g. `403
  Restriction violated`) are visible instead of only appearing in prod logs.
  """

  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Player
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Search

  @poll_interval :timer.seconds(5)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :poll, @poll_interval)

    socket =
      socket
      |> assign(:raw_state, :not_loaded)
      |> assign(:devices, :not_loaded)
      |> assign(:last_action, nil)
      |> assign(:auto_refresh, true)
      |> assign(:track_query, "")
      |> assign(:track_results, [])
      |> assign(:track_search_error, nil)
      |> refresh()

    {:ok, socket}
  end

  @impl true
  def handle_info(:poll, socket) do
    if connected?(socket), do: Process.send_after(self(), :poll, @poll_interval)
    socket = if socket.assigns.auto_refresh, do: refresh(socket), else: socket
    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket), do: {:noreply, refresh(socket)}

  @impl true
  def handle_event("toggle_auto_refresh", _params, socket) do
    {:noreply, assign(socket, :auto_refresh, !socket.assigns.auto_refresh)}
  end

  @impl true
  def handle_event("action", %{"action" => action}, socket) do
    if spotify_connected?(socket) do
      user_id = socket.assigns.current_scope.user.id
      result = run_action(socket.assigns.current_scope, action)
      Logger.info("[SpotifyDebug] user #{user_id} action=#{action} result=#{inspect(result)}")
      socket = assign(socket, :last_action, %{name: action, result: result, at: DateTime.utc_now()})
      {:noreply, refresh(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search_tracks", %{"query" => query}, socket) do
    socket = assign(socket, :track_query, query)

    case String.trim(query) do
      "" ->
        {:noreply, assign(socket, track_results: [], track_search_error: nil)}

      trimmed ->
        case Search.search_any_track(trimmed) do
          {:ok, tracks} -> {:noreply, assign(socket, track_results: tracks, track_search_error: nil)}
          {:error, reason} -> {:noreply, assign(socket, track_results: [], track_search_error: reason)}
        end
    end
  end

  @impl true
  def handle_event("load_track", %{"spotify_id" => spotify_id}, socket) do
    track = Enum.find(socket.assigns.track_results, &(&1.provider_ids.spotify == spotify_id))

    if track && spotify_connected?(socket) do
      user_id = socket.assigns.current_scope.user.id
      result = Player.start_resume_playback(socket.assigns.current_scope, track)

      Logger.info(
        "[SpotifyDebug] user #{user_id} load_track spotify_id=#{spotify_id} name=#{track.name} result=#{inspect(result)}"
      )

      socket =
        socket
        |> assign(:last_action, %{name: "load: #{track.name}", result: result, at: DateTime.utc_now()})
        |> assign(:track_query, "")
        |> assign(:track_results, [])

      {:noreply, refresh(socket)}
    else
      {:noreply, socket}
    end
  end

  defp refresh(socket) do
    if spotify_connected?(socket) do
      scope = socket.assigns.current_scope

      socket
      |> assign(:raw_state, Player.raw_playback_state(scope))
      |> assign(:devices, Player.devices(scope))
      |> assign(:refreshed_at, DateTime.utc_now())
    else
      socket
      |> assign(:raw_state, {:error, :no_spotify_account_linked})
      |> assign(:devices, {:error, :no_spotify_account_linked})
      |> assign(:refreshed_at, DateTime.utc_now())
    end
  end

  defp spotify_connected?(socket), do: !!socket.assigns.current_scope.user.spotify

  defp run_action(scope, "play"), do: Player.start_playback(scope, nil)
  defp run_action(scope, "pause"), do: Player.pause_playback(scope)
  defp run_action(scope, "next"), do: Player.next_track(scope)
  defp run_action(scope, "previous"), do: Player.previous_track(scope)
  defp run_action(scope, "shuffle_on"), do: Player.toggle_playback_shuffle(scope, true)
  defp run_action(scope, "shuffle_off"), do: Player.toggle_playback_shuffle(scope, false)
  defp run_action(scope, "repeat_track"), do: Player.set_repeat_mode(scope, :track)
  defp run_action(scope, "repeat_context"), do: Player.set_repeat_mode(scope, :context)
  defp run_action(scope, "repeat_off"), do: Player.set_repeat_mode(scope, :off)

  defp status_variant(status) when status in [200, 202, 204], do: "success"
  defp status_variant(status) when status in [400, 401, 403, 404, 429], do: "warning"
  defp status_variant(_), do: "error"

  defp pretty(term), do: inspect(term, pretty: true, limit: :infinity, printable_limit: :infinity)
end
