defmodule PremiereEcouteWeb.Components.Header do
  @moduledoc """
  Provides header component for navigation and user menu.
  """
  use PremiereEcouteWeb, :html

  @doc """
  Renders the application header with navigation and user menu.
  """
  attr :current_user, :any, default: nil, doc: "the current authenticated user"
  attr :current_page, :string, default: nil, doc: "the current page identifier"

  def app_header(assigns) do
    ~H"""
    <header
      class="border-b px-6 py-4"
      style="background-color: var(--color-dark-900); border-color: var(--color-dark-800);"
    >
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <div
            class="w-10 h-10 rounded-lg flex items-center justify-center"
            style="background-color: var(--color-primary-600);"
          >
            <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
              <path d="M18 3a1 1 0 00-1.196-.98L3 6.687a1 1 0 000 1.838l4.49 1.497L9.5 14.75a1 1 0 001.838 0L15.014 10H18a1 1 0 001-1V4a1 1 0 00-1-1z" />
            </svg>
          </div>
          <.link
            navigate={~p"/"}
            class="text-2xl font-bold hover:opacity-80 transition-opacity"
            style="color: var(--color-primary-400);"
          >
            Premiere Ecoute
          </.link>
        </div>

        <div class="flex items-center space-x-4">
          <%= if @current_user do %>
            <!-- AIDEV-NOTE: Authenticated user navigation -->
            <!-- User Menu Dropdown -->
            <div class="relative" x-data="{ open: false }">
              <button
                @click="open = !open"
                class="inline-flex items-center px-3 py-2 border rounded-lg text-sm font-medium text-gray-300 hover:text-white transition-colors"
                style="border-color: var(--color-dark-700); background-color: var(--color-dark-900);"
              >
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                  />
                </svg>
                {@current_user.twitch_username || ""}
                <svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M19 9l-7 7-7-7"
                  />
                </svg>
              </button>
              
    <!-- Dropdown Menu -->
              <div
                x-show="open"
                @click.away="open = false"
                x-transition:enter="transition ease-out duration-100"
                x-transition:enter-start="transform opacity-0 scale-95"
                x-transition:enter-end="transform opacity-100 scale-100"
                x-transition:leave="transition ease-in duration-75"
                x-transition:leave-start="transform opacity-100 scale-100"
                x-transition:leave-end="transform opacity-0 scale-95"
                class="absolute right-0 mt-2 w-48 bg-gray-800 rounded-lg shadow-lg border border-gray-700 z-50"
                style="display: none;"
              >
                <div class="py-1">
                  <!-- My Sessions (first item) -->
                  <.link
                    navigate={~p"/sessions"}
                    class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white transition-colors"
                  >
                    <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
                      />
                    </svg>
                    My Sessions
                  </.link>
                  
    <!-- Create Session (second item) -->
                  <.link
                    navigate={~p"/sessions/discography/album/select"}
                    class="flex items-center px-4 py-2 text-sm text-white hover:bg-gray-700 hover:text-gray-200 transition-colors"
                  >
                    <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 6v6m0 0v6m0-6h6m-6 0H6"
                      />
                    </svg>
                    Create Session
                  </.link>
                  
    <!-- Divider -->
                  <div class="border-t border-gray-600 my-1"></div>
                  
    <!-- Account -->
                  <.link
                    navigate={~p"/account"}
                    class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white transition-colors"
                  >
                    <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                      />
                    </svg>
                    Account
                  </.link>
                  
    <!-- Log Out -->
                  <.link
                    href={~p"/users/log-out"}
                    method="delete"
                    class="flex items-center px-4 py-2 text-sm text-red-300 hover:bg-gray-700 hover:text-red-200 transition-colors"
                  >
                    <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"
                      />
                    </svg>
                    Log Out
                  </.link>
                </div>
              </div>
            </div>
          <% else %>
            <!-- AIDEV-NOTE: Anonymous user navigation -->
            <.link
              href={~p"/auth/twitch"}
              class="inline-flex items-center px-4 py-2 border rounded-lg text-sm font-medium text-purple-300 hover:text-purple-200 transition-colors"
              style="border-color: var(--color-purple-600); background-color: var(--color-dark-900);"
            >
              <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
                <path d="M11.571 4.714h1.715v5.143H11.57zm4.715 0H18v5.143h-1.714zM6 0L1.714 4.286v15.428h5.143V24l4.286-4.286h3.428L22.286 12V0zm14.571 11.143l-3.428 3.428h-3.429l-3 3v-3H6.857V1.714h13.714Z" />
              </svg>
              Connect with Twitch
            </.link>
          <% end %>
        </div>
      </div>
    </header>
    """
  end
end
