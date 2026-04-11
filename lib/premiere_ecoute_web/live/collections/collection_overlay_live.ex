defmodule PremiereEcouteWeb.Collections.CollectionOverlayLive do
  @moduledoc """
  OBS streaming overlay LiveView for collection sessions.

  Displays a horizontal A/B vote share bar in real time during active vote windows.
  Transparent when no vote is open. Designed to be used as a browser source in OBS.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Collections
  alias PremiereEcoute.Collections.CollectionSession
  alias PremiereEcouteCore.Cache

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    user = User.get_user_by_username(username)
    broadcaster_id = user && user.twitch && user.twitch.user_id

    {session_id, votes_a, votes_b, vote_open} = load_state(broadcaster_id)

    if connected?(socket) && session_id do
      PremiereEcoute.PubSub.subscribe("collection:#{session_id}")
    end

    if connected?(socket) && user do
      PremiereEcoute.PubSub.subscribe("playback:#{user.id}")
    end

    socket =
      socket
      |> assign(:broadcaster_id, broadcaster_id)
      |> assign(:session_id, session_id)
      |> assign(:votes_a, votes_a)
      |> assign(:votes_b, votes_b)
      |> assign(:vote_open, vote_open)
      |> assign(:play_ding, false)
      |> assign(:duel_sound, duel_sound_file(session_id))
      |> assign(:color_primary, Accounts.profile(user, [:widget_settings, :color_primary]) || "#3b82f6")
      |> assign(:color_secondary, Accounts.profile(user, [:widget_settings, :color_secondary]) || "#f59e0b")

    {:ok, socket}
  end

  # ── PubSub handlers ───────────────────────────────────────────────────────

  @impl true
  def handle_info({:collection_started, session_id}, socket) do
    PremiereEcoute.PubSub.subscribe("collection:#{session_id}")
    {_, votes_a, votes_b, vote_open} = load_state(socket.assigns.broadcaster_id)

    {:noreply,
     assign(socket,
       session_id: session_id,
       votes_a: votes_a,
       votes_b: votes_b,
       vote_open: vote_open,
       duel_sound: duel_sound_file(session_id)
     )}
  end

  @impl true
  def handle_info({:vote_update, %{votes_a: a, votes_b: b}}, socket) do
    {:noreply, assign(socket, votes_a: a, votes_b: b)}
  end

  @impl true
  def handle_info(:vote_open, socket) do
    {:noreply, assign(socket, vote_open: true, votes_a: 0, votes_b: 0)}
  end

  @impl true
  def handle_info({:vote_closed, _track_id, %{votes_a: a, votes_b: b}}, socket) do
    {:noreply, assign(socket, vote_open: false, votes_a: a, votes_b: b)}
  end

  @impl true
  def handle_info({:vote_closed, _track_id}, socket) do
    {:noreply, assign(socket, vote_open: false)}
  end

  @impl true
  def handle_info({:track_decided, _track_id, _decision}, socket) do
    {:noreply, assign(socket, votes_a: 0, votes_b: 0, vote_open: false)}
  end

  @impl true
  def handle_info(:session_started, socket) do
    {_, votes_a, votes_b, vote_open} = load_state(socket.assigns.broadcaster_id)
    {:noreply, assign(socket, votes_a: votes_a, votes_b: votes_b, vote_open: vote_open)}
  end

  @impl true
  def handle_info({:session_completed, _kept_count}, socket) do
    {:noreply, assign(socket, votes_a: 0, votes_b: 0, vote_open: false)}
  end

  @impl true
  def handle_info({:duel_reminder, nil}, socket) do
    {:noreply, assign(socket, :play_ding, not is_nil(socket.assigns.duel_sound))}
  end

  def handle_info({:duel_reminder, _}, socket) do
    {:noreply, assign(socket, :play_ding, false)}
  end

  @impl true
  def handle_info(_event, socket), do: {:noreply, socket}

  # ── Helpers ───────────────────────────────────────────────────────────────

  # AIDEV-NOTE: cache is keyed by broadcaster_id (Twitch user_id string);
  # returns {session_id, votes_a, votes_b, vote_open}
  defp load_state(nil), do: {nil, 0, 0, false}

  defp load_state(broadcaster_id) do
    case Cache.get(:collections, broadcaster_id) do
      {:ok, %{session_id: sid} = cached} ->
        {
          sid,
          Map.get(cached, :votes_a, 0),
          Map.get(cached, :votes_b, 0),
          not is_nil(Map.get(cached, :active_track_id))
        }

      _ ->
        {nil, 0, 0, false}
    end
  end

  defp duel_sound_file(nil), do: nil

  defp duel_sound_file(session_id) do
    case Collections.get_session(session_id) do
      %CollectionSession{options: %{"duel_sound" => sound}} when is_binary(sound) -> "/audio/#{sound}.mp3"
      _ -> nil
    end
  end

  # Returns the percentage width for each side of the bar.
  def bar_pct(0, 0, _side), do: 50
  def bar_pct(a, b, :a), do: trunc(a / (a + b) * 100)
  def bar_pct(a, b, :b), do: trunc(b / (a + b) * 100)
end
