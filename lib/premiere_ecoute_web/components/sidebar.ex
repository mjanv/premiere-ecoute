defmodule PremiereEcouteWeb.Components.Sidebar do
  @moduledoc """
  Left sidebar component with navigation sections for authenticated users.

  Provides "Mes activités" section with:
  - Nouvelle session
  - Mes sessions
  - Rétrospective

  And "Followed channels" section with list of followed streamers.
  """
  use PremiereEcouteWeb, :html

  @doc """
  Renders the left sidebar with navigation sections.
  Only visible for authenticated users with appropriate permissions.
  """
  attr :current_user, :any, default: nil, doc: "the current authenticated user"
  attr :current_scope, :any, default: nil, doc: "the current user scope"
  attr :current_page, :string, default: nil, doc: "current page identifier for highlighting active nav items"

  def left_sidebar(assigns) do
    ~H"""
    <%= if @current_user do %>
      <!-- AIDEV-NOTE: Left sidebar navigation - only shown to authenticated users -->
      <aside class="w-64 flex flex-col border-r" style="background-color: var(--color-dark-900); border-color: var(--color-dark-800);">
        <!-- Scrollable content area -->
        <div class="flex-1 overflow-y-auto">
          <div class="p-6">
            <!-- Mes activités section -->
            <%= if @current_user.role in [:streamer, :admin] do %>
              <div class="mb-6">
                <h3 class="text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3 flex items-center">
                  <.icon name="hero-musical-note" class="w-4 h-4 mr-2" />
                  {gettext("My Activities")}
                </h3>
                <nav class="space-y-1">
                  <.sidebar_link
                    href={~p"/sessions/discography/album/select"}
                    current_page={@current_page}
                    page_id="new_session"
                    icon="hero-plus"
                  >
                    {gettext("New Session")}
                  </.sidebar_link>

                  <.sidebar_link href={~p"/sessions"} current_page={@current_page} page_id="my_sessions" icon="hero-rectangle-stack">
                    {gettext("My Sessions")}
                  </.sidebar_link>

                  <.sidebar_link
                    href={~p"/sessions/wrapped/retrospective"}
                    current_page={@current_page}
                    page_id="retrospective"
                    icon="hero-chart-bar"
                  >
                    {gettext("Retrospective")}
                  </.sidebar_link>
                </nav>
              </div>
            <% end %>
            
    <!-- Followed Channels section -->
            <%= if @current_user && has_loaded_channels?(@current_user) && !Enum.empty?(@current_user.channels) do %>
              <div class="mb-6">
                <h3 class="text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3 flex items-center">
                  <.icon name="hero-user-group" class="w-4 h-4 mr-2" />
                  {gettext("Followed Channels")}
                </h3>
                <nav class="space-y-1">
                  <%= for channel <- @current_user.channels |> Enum.take(10) do %>
                    <.sidebar_channel_link channel={channel} />
                  <% end %>

                  <%= if has_loaded_channels?(@current_user) && length(@current_user.channels) > 10 do %>
                    <.sidebar_link
                      href={~p"/users/follows"}
                      current_page={@current_page}
                      page_id="all_follows"
                      icon="hero-ellipsis-horizontal"
                      class="text-sm"
                    >
                      {gettext("View all")} ({if has_loaded_channels?(@current_user), do: length(@current_user.channels), else: "..."})
                    </.sidebar_link>
                  <% end %>
                </nav>
              </div>
            <% else %>
              <!-- Empty state for no followed channels -->
              <div class="mb-6">
                <h3 class="text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3 flex items-center">
                  <.icon name="hero-user-group" class="w-4 h-4 mr-2" />
                  {gettext("Followed Channels")}
                </h3>
                <div class="text-sm text-gray-500 p-3 border rounded-lg" style="border-color: var(--color-dark-700);">
                  <p class="mb-2">{gettext("No followed channels yet")}</p>
                  <.link href={~p"/users/follows"} class="text-purple-400 hover:text-purple-300 underline">
                    {gettext("Discover streamers")}
                  </.link>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Theme toggle fixed at bottom of sidebar -->
        <div class="p-6">
          <div class="flex justify-center">
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
          </div>
        </div>
      </aside>
    <% end %>
    """
  end

  @doc """
  Renders a sidebar navigation link with icon and active state.
  """
  attr :href, :string, required: true
  attr :current_page, :string, default: nil
  attr :page_id, :string, required: true
  attr :icon, :string, required: true
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def sidebar_link(assigns) do
    ~H"""
    <.link
      href={@href}
      class={[
        "flex items-center px-3 py-2 text-base font-medium rounded-lg transition-colors",
        if @current_page == @page_id do
          "text-white" <> " " <> "bg-purple-600"
        else
          "text-gray-300 hover:text-white hover:bg-gray-800"
        end,
        @class
      ]}
    >
      <.icon name={@icon} class="w-5 h-5 mr-3" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :channel, :map, required: true

  defp sidebar_channel_link(assigns) do
    ~H"""
    <div class="flex items-center px-3 py-2 text-base font-medium text-gray-300 hover:text-white hover:bg-gray-800 rounded-lg transition-colors cursor-pointer">
      <div class="w-7 h-7 rounded-full bg-purple-600 border border-gray-700 flex items-center justify-center text-white font-semibold text-sm mr-3">
        {String.upcase(String.first(@channel.twitch_username || @channel.email))}
      </div>
      <span class="truncate">
        {@channel.twitch_username || @channel.email}
      </span>
    </div>
    """
  end

  # AIDEV-NOTE: Helper function to safely check if channels association is loaded
  defp has_loaded_channels?(nil), do: false
  defp has_loaded_channels?(%{channels: %Ecto.Association.NotLoaded{}}), do: false
  defp has_loaded_channels?(%{channels: _}), do: true
end
