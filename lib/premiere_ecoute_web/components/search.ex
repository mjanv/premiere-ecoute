defmodule PremiereEcouteWeb.Components.Search do
  @moduledoc """
  Search components.

  Provides search bar components with real-time debounced search functionality and customizable placeholders.
  """

  use Phoenix.Component

  attr :query, :string, required: true
  attr :placeholder, :string, required: false, default: "..."

  def searchbar(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row gap-4 mb-6">
      <div class="flex-1">
        <form phx-change="search">
          <div class="relative">
            <svg
              class="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-slate-400"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
              />
            </svg>
            <input
              type="text"
              value={@query}
              name="query"
              phx-debounce="300"
              placeholder={@placeholder}
              class="w-full pl-10 pr-4 py-2 bg-slate-800/50 border border-slate-600/50 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
            />
          </div>
        </form>
      </div>
    </div>
    """
  end
end
