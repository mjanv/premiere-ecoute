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
                  <!-- AIDEV-NOTE: Session management links moved to left sidebar, keeping only account-related items here -->

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
    """
  end
end
