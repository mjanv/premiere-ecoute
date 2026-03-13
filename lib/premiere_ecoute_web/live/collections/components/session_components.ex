defmodule PremiereEcouteWeb.Collections.Components.SessionComponents do
  @moduledoc """
  Collection session UI components.

  Provides reusable Phoenix components for displaying session details including source information (album/playlist), statistics, voting interface, vote distribution graphs, progress tracking, and visibility controls.
  """

  use Phoenix.Component
  use Gettext, backend: PremiereEcoute.Gettext

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

end
