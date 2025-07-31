defmodule PremiereEcouteWeb.Components.Header do
  @moduledoc """
  Provides header component for navigation and user menu.
  """
  use PremiereEcouteWeb, :html

  @doc """
  Renders the application header with navigation and user menu.
  """
  attr :current_user, :any, default: nil, doc: "the current authenticated user"
  attr :current_scope, :any, default: nil, doc: "the current user scope (including impersonation context)"
  attr :current_page, :string, default: nil, doc: "the current page identifier"

  def app_header(assigns) do
    ~H"""
    <!-- AIDEV-NOTE: Impersonation banner - shown when admin is impersonating another user -->
    <%= if @current_scope && Map.get(@current_scope, :impersonating?, false) do %>
      <div class="bg-yellow-600 px-6 py-2">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
              <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span class="text-white font-medium">
              Admin Impersonation: Viewing as {@current_scope.user.twitch_username}
            </span>
          </div>
          <.link
            href={~p"/admin/impersonation"}
            method="delete"
            class="bg-white text-yellow-600 px-4 py-2 rounded text-sm font-medium hover:bg-gray-100 transition-colors"
          >
            Switch Back to Admin
          </.link>
        </div>
      </div>
    <% end %>

    <header class="border-b px-6 py-4" style="background-color: var(--color-dark-900); border-color: var(--color-dark-800);">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <div class="w-10 h-10 rounded-lg flex items-center justify-center" style="background-color: var(--color-primary-600);">
            <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" />
            </svg>
          </div>
          <.link href={~p"/"} class="text-2xl font-bold hover:opacity-80 transition-opacity" style="color: var(--color-primary-400);">
            Premiere Ecoute
          </.link>
        </div>

        <div class="flex items-center space-x-4">
          <!-- AIDEV-NOTE: Theme Toggle - positioned left of language selection -->
          <!-- AIDEV-NOTE: Theme Toggle - Visual toggle switch with sliding indicator -->
          <!-- Theme Toggle -->
          <label class="relative inline-flex items-center cursor-pointer group" title="Toggle theme">
            <!-- Hidden checkbox that controls theme -->
            <input type="checkbox" class="theme-controller sr-only" value="light" />
            
    <!-- Toggle Track -->
            <div
              class="relative w-14 h-7 rounded-full transition-colors duration-300 ease-in-out"
              style="background-color: var(--color-dark-700);"
            >
              
    <!-- Toggle Slider -->
              <div class="absolute top-0.5 left-0.5 w-6 h-6 bg-white rounded-full shadow-lg transform transition-transform duration-300 ease-in-out flex items-center justify-center">
                <!-- Moon icon (default/dark theme) -->
                <svg
                  class="w-3 h-3 text-gray-700 transition-opacity duration-200"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"
                  />
                </svg>
              </div>
            </div>
            
    <!-- Custom CSS for the toggle animation -->
            <style>
              /* When checkbox is checked (light theme active) */
              .theme-controller:checked + div {
                background-color: rgb(34 197 94); /* green-500 */
              }
              .theme-controller:checked + div > div {
                transform: translateX(1.75rem); /* Move slider to right */
              }
              .theme-controller:checked + div > div svg {
                opacity: 0; /* Hide moon icon */
              }
              .theme-controller:checked + div > div::after {
                content: "";
                position: absolute;
                width: 0.75rem;
                height: 0.75rem;
                background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%23374151'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z'/%3E%3C/svg%3E");
                background-size: contain;
                background-repeat: no-repeat;
                opacity: 1;
              }
            </style>
          </label>
          
    <!-- Locale Switcher -->
          <div class="relative" x-data="{ open: false }">
            <button
              @click="open = !open"
              class="inline-flex items-center px-3 py-2 border rounded-lg text-sm font-medium text-gray-300 hover:text-white transition-colors"
              style="border-color: var(--color-dark-700); background-color: var(--color-dark-900);"
            >
              <%= if Gettext.get_locale(PremiereEcoute.Gettext) == "fr" do %>
                <img src="/images/flags/fr.svg" alt="French" class="w-4 h-4 mr-2" />
              <% end %>
              <%= if Gettext.get_locale(PremiereEcoute.Gettext) == "it" do %>
                <img src="/images/flags/it.svg" alt="Italiano" class="w-4 h-4 mr-2" />
              <% end %>
              <%= if Gettext.get_locale(PremiereEcoute.Gettext) == "en" do %>
                <img src="/images/flags/en.svg" alt="English" class="w-4 h-4 mr-2" />
              <% end %>
              <svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
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
              class="absolute right-0 mt-2 w-32 bg-gray-800 rounded-lg shadow-lg border border-gray-700 z-50"
              style="display: none;"
            >
              <div class="py-1">
                <a
                  href="?locale=fr"
                  class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white transition-colors"
                >
                  <img src="/images/flags/fr.svg" alt="French" class="w-4 h-4 mr-3" /> Français
                </a>
                <a
                  href="?locale=it"
                  class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white transition-colors"
                >
                  <img src="/images/flags/it.svg" alt="French" class="w-4 h-4 mr-3" /> Italiano
                </a>
                <a
                  href="?locale=en"
                  class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white transition-colors"
                >
                  <img src="/images/flags/en.svg" alt="English" class="w-4 h-4 mr-3" /> English
                </a>
              </div>
            </div>
          </div>

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
                {@current_user.twitch_username || @current_user.email}
                <svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
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
                  <!-- Session management (only for streamers and admins) -->
                  <%= if @current_user.role in [:streamer, :admin] do %>
                    <!-- Album Dashboard (first item) -->
                    <.link
                      href={~p"/sessions/wrapped/retrospective"}
                      class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white transition-colors"
                    >
                      <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                        />
                      </svg>
                      {gettext("Retrospective")}
                    </.link>
                    
    <!-- My Sessions (second item) -->
                    <.link
                      href={~p"/sessions"}
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
                      {gettext("My Sessions")}
                    </.link>
                    
    <!-- Create Session (third item) -->
                    <.link
                      href={~p"/sessions/discography/album/select"}
                      class="flex items-center px-4 py-2 text-sm text-white hover:bg-gray-700 hover:text-gray-200 transition-colors"
                    >
                      <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m-6 0h6m-6 0H6" />
                      </svg>
                      {gettext("Create Session")}
                    </.link>
                  <% end %>
                  
    <!-- Admin (if admin user) -->
                  <%= if @current_user.role == :admin do %>
                    <!-- Divider -->
                    <div class="border-t border-gray-600 my-1"></div>
                    <.link
                      href={~p"/admin"}
                      class="flex items-center px-4 py-2 text-sm text-white hover:bg-gray-700 hover:text-gray-200 transition-colors"
                    >
                      <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
                        />
                      </svg>
                      {gettext("Admin")}
                    </.link>
                  <% end %>
                  
    <!-- AIDEV-NOTE: Dev mode fake Twitch link for testing -->
                  <%= if Application.get_env(:premiere_ecoute, :environment) == :dev and @current_user.twitch_user_id do %>
                    <!-- Divider -->
                    <div class="border-t border-gray-600 my-1"></div>
                    <a
                      href={"http://localhost:4001/#{@current_user.twitch_user_id}/chat"}
                      target="_blank"
                      class="flex items-center px-4 py-2 text-sm text-purple-300 hover:bg-gray-700 hover:text-purple-200 transition-colors"
                    >
                      <svg class="w-4 h-4 mr-3" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M11.571 4.714h1.715v5.143H11.57zm4.715 0H18v5.143h-1.714zM6 0L1.714 4.286v15.428h5.143V24l4.286-4.286h3.428L22.286 12V0zm14.571 11.143l-3.428 3.428h-3.429l-3 3v-3H6.857V1.714h13.714Z" />
                      </svg>
                      Fake Twitch Chat
                    </a>
                  <% end %>
                  
    <!-- Divider -->
                  <div class="border-t border-gray-600 my-1"></div>
                  
    <!-- Follows -->
                  <.link
                    href={~p"/users/follows"}
                    class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white transition-colors"
                  >
                    <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"
                      />
                    </svg>
                    {gettext("Follows")}
                  </.link>
                  
    <!-- Account -->
                  <.link
                    href={~p"/users/account"}
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
                    {gettext("Account")}
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
                    {gettext("Log Out")}
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
              {gettext("Connect with Twitch")}
            </.link>
          <% end %>
        </div>
      </div>
    </header>

    <!-- AIDEV-NOTE: Spotify connection notification for streamers -->
    <%= if @current_user && @current_user.role in [:streamer, :admin] && !has_spotify_connected?(@current_user) do %>
      <div class="bg-green-600 px-6 py-2">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.48.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.32 11.28-1.02 15.721 1.621.539.3.719 1.02.42 1.56-.299.421-1.02.599-1.559.3z" />
            </svg>
            <span class="text-white font-medium">
              Connect your Spotify account to manage music playback
            </span>
          </div>
          <.link
            href={~p"/auth/spotify"}
            class="inline-flex items-center px-4 py-2 bg-white text-green-600 rounded-lg text-sm font-medium hover:bg-gray-100 transition-colors"
          >
            Connect Spotify
          </.link>
        </div>
      </div>
    <% end %>
    """
  end

  # AIDEV-NOTE: Helper function to check if user has Spotify connected
  defp has_spotify_connected?(user) do
    user.spotify_access_token != nil && user.spotify_refresh_token != nil
  end
end
