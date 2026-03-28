defmodule PremiereEcouteWeb.Collections.Components.SessionComponents do
  @moduledoc """
  Collection session UI components.

  Provides reusable Phoenix components for displaying session details including source information (album/playlist), statistics, voting interface, vote distribution graphs, progress tracking, and visibility controls.
  """

  use Phoenix.Component
  use Gettext, backend: PremiereEcoute.Gettext

  attr :player_state, :map, required: true

  def player_bar(%{player_state: nil} = assigns), do: ~H""

  def player_bar(assigns) do
    ~H"""
    <div class="bg-white/5 rounded-lg border border-white/10 text-xs overflow-hidden">
      <div class="flex items-center gap-3 px-3 py-2">
        <%= if @player_state["is_playing"] do %>
          <span class="w-2 h-2 bg-green-400 rounded-full animate-pulse flex-shrink-0"></span>
        <% else %>
          <span class="w-2 h-2 bg-gray-500 rounded-full flex-shrink-0"></span>
        <% end %>

        <span class="text-gray-400 flex-shrink-0">
          {if @player_state["device"], do: @player_state["device"]["name"], else: gettext("No device")}
        </span>

        <%= if @player_state["item"] do %>
          <span class="text-white font-medium truncate">
            {Enum.map_join(@player_state["item"]["artists"], ", ", & &1["name"])} - {@player_state["item"]["name"]}
          </span>
          <span class="text-gray-500 flex-shrink-0 ml-auto">
            {PremiereEcouteCore.Duration.timer(@player_state["progress_ms"])} / {PremiereEcouteCore.Duration.timer(
              @player_state["item"]["duration_ms"]
            )}
          </span>
        <% else %>
          <span class="text-gray-600 ml-auto">{gettext("Nothing playing")}</span>
        <% end %>

        <button
          phx-click="toggle_playback"
          class="flex-shrink-0 p-1 bg-white/10 hover:bg-white/20 rounded transition-colors"
        >
          <%= if @player_state["is_playing"] do %>
            <svg class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 24 24">
              <rect x="6" y="4" width="4" height="16" rx="1" /><rect x="14" y="4" width="4" height="16" rx="1" />
            </svg>
          <% else %>
            <svg class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z" />
            </svg>
          <% end %>
        </button>
      </div>
      <%= if @player_state["item"] do %>
        <% progress = trunc(100 * @player_state["progress_ms"] / max(@player_state["item"]["duration_ms"], 1)) %>
        <div class="h-0.5 bg-white/10">
          <div class="h-full bg-green-500 transition-all duration-1000" style={"width: #{progress}%"}></div>
        </div>
      <% end %>
    </div>
    """
  end

  attr :track, :map, required: true
  attr :label, :string, required: true
  attr :accent, :string, default: "purple"
  # AIDEV-NOTE: color overrides accent with a hex string for dynamic profile colors (e.g. duel mode)
  attr :color, :string, default: nil
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
    # AIDEV-NOTE: resolve color-dependent styles once here so the template stays clean
    assigns =
      assign(assigns,
        border_style:
          if assigns[:color] do
            "border-color: #{assigns.color}4d;"
          else
            case assigns.accent do
              "blue" -> "border-color: rgba(59,130,246,0.3);"
              "amber" -> "border-color: rgba(245,158,11,0.3);"
              _ -> nil
            end
          end,
        divider_style:
          if assigns[:color] do
            "background-color: #{assigns.color}4d;"
          else
            case assigns.accent do
              "blue" -> nil
              "amber" -> nil
              _ -> nil
            end
          end,
        divider_class:
          unless assigns[:color] do
            case assigns.accent do
              "blue" -> "bg-blue-500/30"
              "amber" -> "bg-amber-500/30"
              _ -> "bg-white/10"
            end
          end,
        label_style: if(assigns[:color], do: "color: #{assigns.color};"),
        label_class:
          unless assigns[:color] do
            case assigns.accent do
              "blue" -> "text-blue-400"
              "amber" -> "text-amber-400"
              _ -> "text-purple-400"
            end
          end,
        border_class: unless(assigns[:color], do: if(assigns.accent == "purple", do: "border-white/10", else: ""))
      )

    ~H"""
    <div
      class={["bg-white/5 rounded-lg border px-4 py-3 flex items-center gap-4 h-full", @border_class]}
      style={@border_style}
    >
      <%= if @votes != nil do %>
        <div class="flex-shrink-0 text-center w-10">
          <p class="text-xl font-bold text-white leading-none">{@votes}</p>
          <p class="text-xs text-gray-500">votes</p>
        </div>
        <div class={["w-px self-stretch", @divider_class]} style={@divider_style}></div>
      <% end %>
      <div class="min-w-0 flex-1">
        <p class={["text-xs font-medium mb-1", @label_class]} style={@label_style}>
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
            "flex-shrink-0 p-2.5 rounded-lg text-white transition-all",
            if playing do
              "bg-red-500/20 hover:bg-red-500/40 text-red-400 drop-shadow-[0_0_8px_rgba(239,68,68,0.8)] hover:drop-shadow-[0_0_12px_rgba(239,68,68,1)]"
            else
              "bg-purple-500/20 hover:bg-purple-500/40 text-purple-400 drop-shadow-[0_0_8px_rgba(168,85,247,0.6)] hover:drop-shadow-[0_0_12px_rgba(168,85,247,1)]"
            end
          ]}
        >
          <%= if playing do %>
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <rect x="6" y="4" width="4" height="16" rx="1" /><rect x="14" y="4" width="4" height="16" rx="1" />
            </svg>
          <% else %>
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z" />
            </svg>
          <% end %>
        </button>
      <% end %>
    </div>
    """
  end

  attr :vote_open, :boolean, required: true
  attr :countdown, :integer, default: nil
  attr :mode, :atom, required: true
  attr :votes_a, :integer, default: 0
  attr :votes_b, :integer, default: 0
  attr :round_duration, :integer, default: 60
  attr :color_primary, :string, default: "#3b82f6"
  attr :color_secondary, :string, default: "#f59e0b"

  def vote_controls(assigns) do
    ~H"""
    <div class="flex items-center gap-2 flex-1">
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
        <%= if @mode == :duel do %>
          <button
            phx-click="decide"
            phx-value-decision="kept"
            class="px-3 py-1.5 text-white rounded-lg text-xs font-medium transition-colors"
            style={"background-color: #{@color_primary};"}
          >
            {gettext("Pick A")}
          </button>
          <button
            phx-click="decide"
            phx-value-decision="rejected"
            class="px-3 py-1.5 text-white rounded-lg text-xs font-medium transition-colors"
            style={"background-color: #{@color_secondary};"}
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
end
