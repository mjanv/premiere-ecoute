defmodule PremiereEcouteWeb.Components.Live.HistoryGraphCard do
  @moduledoc """
  A reusable graph card component for Twitch history data visualization.

  Displays a graph with period selectors and a details link, with customizable theming.
  """

  use PremiereEcouteWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class={"rounded-xl border border-#{@color}-500/30 bg-gradient-to-br from-slate-800/50 to-slate-900/50 backdrop-blur overflow-hidden"}>
      <div class="px-6 py-3 border-b border-slate-700/50 flex items-center justify-between">
        <div class="flex gap-3 items-center">
          <h3 class="text-base font-semibold text-white">{@title}</h3>
          <.link
            navigate={@details_path}
            class={"flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium bg-#{@color}-600/10 text-#{@color}-300 hover:bg-#{@color}-600/20 transition-all duration-200 border border-#{@color}-500/30 hover:border-#{@color}-500/50 group"}
          >
            <span>Details</span>
            <svg
              class="w-3 h-3 transition-transform duration-200 group-hover:translate-x-0.5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
            </svg>
          </.link>
        </div>
        <div class="flex gap-2">
          <%= for period <- @periods do %>
            <button
              phx-click="change_period"
              phx-value-graph={@graph_name}
              phx-value-period={period}
              class={"px-3 py-1 rounded-lg text-sm font-medium transition-all duration-200 #{if @current_period == period, do: "bg-#{@color}-600 text-white", else: "bg-slate-700/50 text-slate-300 hover:bg-slate-700"}"}
            >
              {String.capitalize(period)}
            </button>
          <% end %>
        </div>
      </div>
      <div class="p-6">
        <.live_component
          module={PremiereEcouteWeb.Components.Live.Graph}
          id={"#{@graph_name}-graph"}
          title=""
          data={@graph_data}
          x="date"
          y={@y_axis}
        />
      </div>
    </div>
    """
  end
end
