defmodule PremiereEcouteWeb.Components.Navigation.DayNav do
  @moduledoc """
  Day navigation component for the radio viewer.

  Renders prev/next day arrows with visibility controlled by date bounds.
  """

  use Phoenix.Component
  use PremiereEcouteWeb, :verified_routes

  @doc """
  Renders a previous/next day navigation header.

  Arrows are only rendered when navigation is possible within the retention window.
  """
  attr :username, :string, required: true
  attr :date, Date, required: true
  attr :today, Date, required: true
  attr :oldest_date, Date, required: true

  def day_nav(assigns) do
    ~H"""
    <div class="flex items-center gap-6 mb-10">
      <%= if Date.compare(@date, @oldest_date) == :gt do %>
        <.link
          patch={~p"/radio/#{@username}/#{Date.to_iso8601(Date.add(@date, -1))}"}
          class="flex items-center justify-center w-12 h-12 rounded-full bg-purple-800 border-2 border-purple-400 text-purple-100 hover:bg-purple-600 hover:border-purple-200 hover:text-white transition-all duration-200"
          aria-label="Previous day"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
        </.link>
      <% else %>
        <span class="w-12 h-12"></span>
      <% end %>

      <div class="flex-1 text-center">
        <h1 class="text-2xl sm:text-4xl font-bold text-white">
          {Calendar.strftime(@date, "%-d %B %Y")}
        </h1>
      </div>

      <%= if Date.compare(@date, @today) == :lt do %>
        <.link
          patch={
            if Date.add(@date, 1) == @today,
              do: ~p"/radio/#{@username}/today",
              else: ~p"/radio/#{@username}/#{Date.to_iso8601(Date.add(@date, 1))}"
          }
          class="flex items-center justify-center w-12 h-12 rounded-full bg-purple-800 border-2 border-purple-400 text-purple-100 hover:bg-purple-600 hover:border-purple-200 hover:text-white transition-all duration-200"
          aria-label="Next day"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
          </svg>
        </.link>
      <% else %>
        <span class="w-12 h-12"></span>
      <% end %>
    </div>
    """
  end
end
