defmodule PremiereEcouteWeb.Collections.CollectionSessionLive do
  @moduledoc """
  Collection session curation LiveView.

  Main UI for curating a playlist live. Handles three selection modes:
  - streamer_choice: Keep / Skip / Reject buttons per track
  - viewer_vote: vote bar + countdown timer; streamer finalizes
  - duel: two tracks, viewer picks A or B; streamer finalizes

  Subscribes to PubSub for live vote updates and vote window close events.
  Decision state (kept/rejected/skipped) is read directly from session arrays.
  """

  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Collections.CollectionSession
  alias PremiereEcoute.Collections.CollectionSession.Commands.CloseVoteWindow
  alias PremiereEcoute.Collections.CollectionSession.Commands.CompleteCollectionSession
  alias PremiereEcoute.Collections.CollectionSession.Commands.DecideTrack
  alias PremiereEcoute.Collections.CollectionSession.Commands.OpenVoteWindow
  alias PremiereEcoute.Collections.CollectionSession.Commands.StartCollectionSession
  alias PremiereEcoute.Collections.Tracklist
  alias PremiereEcouteCore.Cache
  alias PremiereEcouteCore.CommandBus

  @impl true
  def mount(%{"id" => id}, _session, %{assigns: %{current_scope: scope}} = socket) do
    session_id = String.to_integer(id)
    session = CollectionSession.get(session_id)

    if is_nil(session) || session.user_id != scope.user.id do
      socket
      |> put_flash(:error, gettext("Collection not found"))
      |> redirect(to: ~p"/collections")
      |> then(fn socket -> {:ok, socket} end)
    else
      if connected?(socket) do
        PremiereEcoute.PubSub.subscribe("collection:#{session_id}")
      end

      broadcaster_id = scope.user.twitch.user_id
      {tracks, votes_a, votes_b, active_track_id, duel_track_id, vote_open} = load_cache(broadcaster_id)

      socket
      |> assign(:session, session)
      |> assign(:session_id, session_id)
      |> assign(:broadcaster_id, broadcaster_id)
      |> assign(:scope, scope)
      |> assign(:tracks, tracks)
      |> assign(:original_tracks, tracks)
      |> assign(:active_track_id, active_track_id)
      |> assign(:duel_track_id, duel_track_id)
      |> assign(:votes_a, votes_a)
      |> assign(:votes_b, votes_b)
      |> assign(:vote_open, vote_open)
      |> assign(:countdown, nil)
      |> assign(:playing_track_id, nil)
      |> assign(:hide_decided, false)
      |> assign(:show_end_modal, false)
      |> assign(:round_mode, :streamer_choice)
      |> assign(:round_duration, 60)
      |> then(fn socket -> {:ok, socket} end)
    end
  end

  # ── Cache helpers ─────────────────────────────────────────────────────────

  defp load_cache(session_id) do
    case Cache.get(:collections, session_id) do
      {:ok, nil} ->
        {[], 0, 0, nil, nil, false}

      {:ok, cached} ->
        {
          Map.get(cached, :tracks, []),
          Map.get(cached, :votes_a, 0),
          Map.get(cached, :votes_b, 0),
          Map.get(cached, :active_track_id),
          Map.get(cached, :duel_track_id),
          not is_nil(Map.get(cached, :active_track_id))
        }

      _ ->
        {[], 0, 0, nil, nil, false}
    end
  end

  # ── PubSub handlers ───────────────────────────────────────────────────────

  @impl true
  def handle_info(:session_started, socket) do
    {tracks, _, _, _, _, _} = load_cache(socket.assigns.broadcaster_id)
    session = CollectionSession.get(socket.assigns.session_id)
    {:noreply, assign(socket, tracks: tracks, session: session)}
  end

  @impl true
  def handle_info({:vote_update, %{votes_a: a, votes_b: b}}, socket) do
    {:noreply, assign(socket, votes_a: a, votes_b: b)}
  end

  @impl true
  def handle_info({:vote_closed, _track_id, %{votes_a: a, votes_b: b}}, socket) do
    {:noreply, assign(socket, votes_a: a, votes_b: b, vote_open: false, countdown: nil)}
  end

  @impl true
  def handle_info({:vote_closed, _track_id}, socket) do
    {:noreply, assign(socket, vote_open: false, countdown: nil)}
  end

  @impl true
  def handle_info({:track_decided, _track_id, _decision}, socket) do
    session = CollectionSession.get(socket.assigns.session_id)

    {:noreply,
     assign(socket,
       session: session,
       votes_a: 0,
       votes_b: 0,
       active_track_id: nil,
       duel_track_id: nil,
       vote_open: false
     )}
  end

  @impl true
  def handle_info({:session_completed, _kept_count}, socket) do
    session = CollectionSession.get(socket.assigns.session_id)
    {:noreply, assign(socket, session: session)}
  end

  @impl true
  def handle_info(:vote_open, socket) do
    {:noreply, assign(socket, vote_open: true)}
  end

  @impl true
  def handle_info({:collection_started, _session_id}, socket), do: {:noreply, socket}

  @impl true
  def handle_info(:tick, %{assigns: %{countdown: nil}} = socket), do: {:noreply, socket}
  def handle_info(:tick, %{assigns: %{countdown: 0}} = socket), do: {:noreply, socket}

  def handle_info(:tick, %{assigns: %{countdown: n}} = socket) do
    Process.send_after(self(), :tick, 1000)
    {:noreply, assign(socket, countdown: n - 1)}
  end

  # ── Commands ─────────────────────────────────────────────────────────────

  @impl true
  def handle_event("start", _params, %{assigns: %{session: session, scope: scope}} = socket) do
    %StartCollectionSession{session_id: session.id, scope: scope}
    |> CommandBus.apply()
    |> case do
      {:ok, started, _events} ->
        {tracks, _, _, _, _, _} = load_cache(socket.assigns.broadcaster_id)
        {:noreply, assign(socket, session: started, tracks: tracks, original_tracks: tracks)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  @impl true
  def handle_event("set_round_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, round_mode: String.to_existing_atom(mode))}
  end

  @impl true
  def handle_event("set_round_duration", %{"duration" => duration}, socket) do
    {:noreply, assign(socket, round_duration: String.to_integer(duration))}
  end

  @impl true
  def handle_event("toggle_hide_decided", _params, socket) do
    {:noreply, assign(socket, :hide_decided, not socket.assigns.hide_decided)}
  end

  @impl true
  def handle_event("open_vote", _params, %{assigns: assigns} = socket) do
    %{session: session, scope: scope, tracks: tracks, round_mode: round_mode, round_duration: round_duration} = assigns
    track = Enum.at(tracks, session.current_index)
    duel = if round_mode == :duel, do: Enum.at(tracks, session.current_index + 1)

    %OpenVoteWindow{
      session_id: session.id,
      scope: scope,
      track_id: track && track.track_id,
      duel_track_id: duel && duel.track_id,
      selection_mode: round_mode,
      vote_duration: round_duration
    }
    |> CommandBus.apply()
    |> case do
      {:ok, _session, _events} ->
        {_, votes_a, votes_b, active_id, duel_id, _} = load_cache(socket.assigns.broadcaster_id)
        Process.send_after(self(), :tick, 1000)

        {:noreply,
         assign(socket,
           vote_open: true,
           votes_a: votes_a,
           votes_b: votes_b,
           active_track_id: active_id,
           duel_track_id: duel_id,
           countdown: round_duration
         )}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  @impl true
  def handle_event("close_vote", _params, %{assigns: %{session: session, scope: scope}} = socket) do
    %CloseVoteWindow{session_id: session.id, scope: scope}
    |> CommandBus.apply()
    |> case do
      {:ok, _session, _events} -> {:noreply, assign(socket, vote_open: false, countdown: nil)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  @impl true
  def handle_event(
        "decide",
        %{"decision" => decision},
        %{assigns: %{session: session, scope: scope, tracks: tracks, round_mode: round_mode}} = socket
      ) do
    decision = String.to_existing_atom(decision)

    case round_mode do
      :streamer_choice ->
        track = Enum.at(tracks, session.current_index)

        %DecideTrack{
          session_id: session.id,
          scope: scope,
          track_id: track && track.track_id,
          decision: decision,
          duel_track_id: nil
        }

      :viewer_vote ->
        track = Enum.at(tracks, session.current_index)

        %DecideTrack{
          session_id: session.id,
          scope: scope,
          track_id: track && track.track_id,
          decision: decision,
          duel_track_id: nil
        }

      :duel ->
        a = Enum.at(tracks, session.current_index)
        b = Enum.at(tracks, session.current_index + 1)

        {winner, loser} =
          case decision do
            :kept -> {a, b}
            :rejected -> {b, a}
          end

        %DecideTrack{
          session_id: session.id,
          scope: scope,
          track_id: winner && winner.track_id,
          decision: :kept,
          duel_track_id: loser && loser.track_id
        }
    end
    |> CommandBus.apply()
    |> case do
      {:ok, session, _events} ->
        {:noreply,
         assign(socket,
           session: session,
           votes_a: 0,
           votes_b: 0,
           vote_open: false,
           active_track_id: nil,
           duel_track_id: nil,
           countdown: nil,
           playing_track_id: nil
         )}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  @impl true
  def handle_event("complete", params, %{assigns: %{session: session, scope: scope}} = socket) do
    %CompleteCollectionSession{
      session_id: session.id,
      scope: scope,
      remove_kept: Map.get(params, "remove_kept") == "true",
      remove_rejected: Map.get(params, "remove_rejected") == "true"
    }
    |> CommandBus.apply()
    |> case do
      {:ok, session, _events} -> {:noreply, assign(socket, session: session, show_end_modal: false)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  @impl true
  def handle_event(
        "shuffle",
        _params,
        %{assigns: %{broadcaster_id: broadcaster_id, tracks: tracks, session: session}} = socket
      ) do
    {:ok, tracks} = Tracklist.shuffle(session, broadcaster_id, tracks)
    {:noreply, assign(socket, tracks: tracks)}
  end

  @impl true
  def handle_event(
        "restore_order",
        _params,
        %{assigns: %{broadcaster_id: broadcaster_id, original_tracks: original_tracks, tracks: tracks, session: session}} = socket
      ) do
    {:ok, tracks} = Tracklist.restore(session, broadcaster_id, tracks, original_tracks)
    {:noreply, assign(socket, tracks: tracks)}
  end

  @impl true
  def handle_event(
        "move_to_top",
        %{"index" => index},
        %{assigns: %{broadcaster_id: broadcaster_id, tracks: tracks, session: session}} = socket
      ) do
    {:ok, tracks} = Tracklist.move_to_top(session, String.to_integer(index), broadcaster_id, tracks)
    {:noreply, assign(socket, tracks: tracks)}
  end

  @impl true
  def handle_event(
        "move_up",
        %{"index" => index},
        %{assigns: %{broadcaster_id: broadcaster_id, tracks: tracks, session: session}} = socket
      ) do
    {:ok, tracks} = Tracklist.reorder(session, String.to_integer(index), -1, broadcaster_id, tracks)
    {:noreply, assign(socket, tracks: tracks)}
  end

  @impl true
  def handle_event(
        "move_down",
        %{"index" => index},
        %{assigns: %{broadcaster_id: broadcaster_id, tracks: tracks, session: session}} = socket
      ) do
    {:ok, tracks} = Tracklist.reorder(session, String.to_integer(index), +1, broadcaster_id, tracks)
    {:noreply, assign(socket, tracks: tracks)}
  end

  @impl true
  def handle_event("play_track", _params, %{assigns: %{tracks: tracks, session: session, scope: scope}} = socket) do
    play(Enum.at(tracks, session.current_index), scope, socket)
  end

  @impl true
  def handle_event("play_track_a", _params, %{assigns: %{tracks: tracks, session: session, scope: scope}} = socket) do
    play(Enum.at(tracks, session.current_index), scope, socket)
  end

  @impl true
  def handle_event("play_track_b", _params, %{assigns: %{tracks: tracks, session: session, scope: scope}} = socket) do
    play(Enum.at(tracks, session.current_index + 1), scope, socket)
  end

  @impl true
  def handle_event("stop_playback", _params, %{assigns: %{scope: scope}} = socket) do
    case SpotifyApi.pause_playback(scope) do
      {:ok, _} ->
        {:noreply, assign(socket, :playing_track_id, nil)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  @impl true
  def handle_event("modal_content_click", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("show_end_modal", _params, socket) do
    {:noreply, assign(socket, :show_end_modal, true)}
  end

  @impl true
  def handle_event("hide_end_modal", _params, socket) do
    {:noreply, assign(socket, :show_end_modal, false)}
  end

  defp play(nil, _scope, socket), do: {:noreply, socket}

  defp play(track, scope, socket) do
    case SpotifyApi.start_resume_playback(scope, track) do
      {:ok, _} -> {:noreply, assign(socket, :playing_track_id, track.track_id)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  # ── Components ────────────────────────────────────────────────────────────

  attr :track, :map, required: true
  attr :label, :string, required: true
  attr :accent, :string, default: "purple"
  attr :votes, :integer, default: nil
  attr :play_event, :string, default: nil
  attr :playing_track_id, :string, default: nil

  def track_card(%{track: nil} = assigns) do
    ~H"""
    <div class="bg-white/5 rounded-lg border border-white/10 px-4 py-3 flex items-center justify-center">
      <p class="text-gray-500 text-sm">{gettext("No track")}</p>
    </div>
    """
  end

  def track_card(assigns) do
    ~H"""
    <div class={[
      "bg-white/5 rounded-lg border px-4 py-3",
      case @accent do
        "blue" -> "border-blue-500/30"
        "amber" -> "border-amber-500/30"
        _ -> "border-white/10"
      end
    ]}>
      <div class="flex items-start justify-between gap-2">
        <div class="min-w-0">
          <p class={[
            "text-xs font-medium mb-1",
            case @accent do
              "blue" -> "text-blue-400"
              "amber" -> "text-amber-400"
              _ -> "text-purple-400"
            end
          ]}>
            {@label}
          </p>
          <p class="text-white font-semibold leading-tight">{@track.name}</p>
          <p class="text-gray-400 text-sm">{@track.artist}</p>
        </div>
        <%= if @play_event do %>
          <% playing = @playing_track_id == @track.track_id %>
          <button
            phx-click={if playing, do: "stop_playback", else: @play_event}
            class={[
              "flex-shrink-0 mt-1 p-1.5 rounded-lg text-white transition-colors",
              if playing do
                "bg-green-600/30 hover:bg-red-600/40"
              else
                "bg-white/10 hover:bg-white/20"
              end
            ]}
          >
            <%= if playing do %>
              <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
                <rect x="6" y="4" width="4" height="16" rx="1" /><rect x="14" y="4" width="4" height="16" rx="1" />
              </svg>
            <% else %>
              <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z" />
              </svg>
            <% end %>
          </button>
        <% end %>
      </div>
      <%= if @votes != nil do %>
        <p class="text-xl font-bold text-white mt-2">
          {@votes} <span class="text-xs text-gray-500 font-normal">{gettext("votes")}</span>
        </p>
      <% end %>
    </div>
    """
  end

  attr :vote_open, :boolean, required: true
  attr :countdown, :integer, default: nil
  attr :mode, :atom, required: true
  attr :votes_a, :integer, default: 0
  attr :votes_b, :integer, default: 0

  def vote_controls(assigns) do
    ~H"""
    <div class="flex items-center gap-2 flex-wrap mt-3">
      <%= if @vote_open do %>
        <span class="text-green-400 text-xs font-medium flex items-center gap-1.5">
          <span class="w-1.5 h-1.5 bg-green-400 rounded-full animate-pulse inline-block"></span>
          {gettext("Vote open")}
        </span>
        <%= if @countdown != nil do %>
          <span class="text-sm font-bold text-white">{@countdown}s</span>
        <% end %>
        <button
          phx-click="close_vote"
          class="ml-auto px-3 py-1.5 bg-orange-600 hover:bg-orange-700 text-white rounded-lg text-xs font-medium transition-colors"
        >
          {gettext("Close early")}
        </button>
      <% else %>
        <button
          phx-click="open_vote"
          class="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-xs font-medium transition-colors"
        >
          {gettext("Open vote")}
        </button>
        <div class="w-px h-4 bg-white/20"></div>
        <%= if @mode == :duel do %>
          <button
            phx-click="decide"
            phx-value-decision="kept"
            class="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-xs font-medium transition-colors"
          >
            {gettext("Pick A")}
          </button>
          <button
            phx-click="decide"
            phx-value-decision="rejected"
            class="px-3 py-1.5 bg-amber-600 hover:bg-amber-700 text-white rounded-lg text-xs font-medium transition-colors"
          >
            {gettext("Pick B")}
          </button>
        <% else %>
          <button
            phx-click="decide"
            phx-value-decision="kept"
            class="px-3 py-1.5 bg-green-600 hover:bg-green-700 text-white rounded-lg text-xs font-medium transition-colors"
          >
            {gettext("Keep")}
          </button>
          <button
            phx-click="decide"
            phx-value-decision="skipped"
            class="px-3 py-1.5 bg-gray-600 hover:bg-gray-700 text-white rounded-lg text-xs font-medium transition-colors"
          >
            {gettext("Skip")}
          </button>
          <button
            phx-click="decide"
            phx-value-decision="rejected"
            class="px-3 py-1.5 bg-red-600 hover:bg-red-700 text-white rounded-lg text-xs font-medium transition-colors"
          >
            {gettext("Reject")}
          </button>
        <% end %>
      <% end %>
    </div>
    """
  end

  # ── View helpers ──────────────────────────────────────────────────────────

  @spec decision_class(atom()) :: String.t()
  def decision_class(:kept), do: "bg-green-600/20 text-green-400 border-green-500/30"
  def decision_class(:rejected), do: "bg-red-600/20 text-red-400 border-red-500/30"
  def decision_class(:skipped), do: "bg-gray-600/20 text-gray-400 border-gray-500/30"

  # AIDEV-NOTE: derives decision from inline session arrays; returns nil if track not yet decided
  @spec track_decision(CollectionSession.t(), String.t()) :: :kept | :rejected | :skipped | nil
  def track_decision(session, track_id) do
    cond do
      track_id in session.kept -> :kept
      track_id in session.rejected -> :rejected
      track_id in session.skipped -> :skipped
      true -> nil
    end
  end

  @spec vote_bar_width(integer(), integer(), :a | :b) :: String.t()
  def vote_bar_width(0, 0, _side), do: "50%"
  def vote_bar_width(a, b, :a), do: "#{trunc(a / (a + b) * 100)}%"
  def vote_bar_width(a, b, :b), do: "#{trunc(b / (a + b) * 100)}%"
end
