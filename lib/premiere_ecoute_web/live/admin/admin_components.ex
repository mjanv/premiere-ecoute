defmodule PremiereEcouteWeb.Admin.AdminComponents do
  @moduledoc """
  Shared function components for admin LiveViews.

  Provides consistent page headers, stat cards, and search bars
  reused across all admin management pages.
  """

  use Phoenix.Component
  use Gettext, backend: PremiereEcoute.Gettext

  # ---------------------------------------------------------------------------
  # Page header
  # ---------------------------------------------------------------------------

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil

  def admin_page_header(assigns) do
    ~H"""
    <div class="mb-8">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between">
        <div>
          <div class="flex items-center gap-2 mb-1">
            <.link
              navigate="/admin"
              class="inline-flex items-center text-sm text-gray-500 hover:text-white transition-colors"
            >
              <svg class="w-3.5 h-3.5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
              {gettext("Dashboard")}
            </.link>
          </div>
          <h1 class="text-3xl font-bold text-white">{@title}</h1>
          <%= if @subtitle do %>
            <p class="mt-2 text-gray-400">{@subtitle}</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Stat card
  # ---------------------------------------------------------------------------

  attr :value, :any, required: true
  attr :label, :string, required: true
  attr :color, :string, default: "gray"
  slot :icon, required: true

  def stat_card(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
      <div class="flex items-center">
        <div class={["p-3 rounded-full", bg_color(@color)]}>
          {render_slot(@icon)}
        </div>
        <div class="ml-4">
          <p class="text-2xl font-semibold text-white">{@value}</p>
          <p class="text-sm text-gray-400">{@label}</p>
        </div>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Search bar
  # ---------------------------------------------------------------------------

  attr :value, :string, default: ""
  attr :placeholder, :string, default: "Search…"
  attr :event, :string, default: "search"
  attr :name, :string, default: "search"
  slot :extra

  def search_bar(assigns) do
    ~H"""
    <form phx-change={@event} class="flex gap-3 mb-4">
      <div class="relative flex-1">
        <svg
          class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0" />
        </svg>
        <input
          type="text"
          name={@name}
          value={@value}
          placeholder={@placeholder}
          class="w-full pl-9 pr-4 py-2 bg-gray-800 border border-gray-600 rounded-md text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent"
          phx-debounce="300"
        />
      </div>
      {render_slot(@extra)}
    </form>
    """
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp bg_color("purple"), do: "bg-purple-900"
  defp bg_color("blue"), do: "bg-blue-900"
  defp bg_color("green"), do: "bg-green-900"
  defp bg_color("yellow"), do: "bg-yellow-900"
  defp bg_color("red"), do: "bg-red-900"
  defp bg_color("teal"), do: "bg-teal-900"
  defp bg_color("pink"), do: "bg-pink-900"
  defp bg_color(_), do: "bg-gray-700"
end
