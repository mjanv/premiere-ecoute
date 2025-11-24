defmodule PremiereEcouteWeb.Components.Sidebar do
  @moduledoc """
  Left sidebar component with navigation sections for authenticated users.
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
      <aside
        class="sidebar w-64 flex flex-col border-r relative"
        style="background-color: var(--color-dark-900); border-color: var(--color-dark-800);"
        phx-hook="SidebarCollapse"
        id="sidebar"
      >
        <script>
          (function() {
            const sidebar = document.getElementById('sidebar');
            if (sidebar && localStorage.getItem('sidebar-collapsed') === 'true') {
              sidebar.classList.add('sidebar-collapsed');
            }
          })();
        </script>
        <button
          data-sidebar-toggle
          class="sidebar-toggle-btn absolute top-2 right-2 p-1.5 rounded-md hover:bg-gray-800 transition-colors z-10"
          title="Toggle sidebar"
        >
          <.icon name="hero-chevron-left" class="w-4 h-4 text-gray-400" />
        </button>
        <!-- Scrollable content area -->
        <div class="flex-1 overflow-y-auto">
          <div class="p-6 pt-10">
            <!-- My Library section -->
            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:playlists, for: @current_user) do %>
              <div class="mb-6">
                <h3 class="sidebar-section-title text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3 flex items-center">
                  <.icon name="hero-rectangle-stack" class="w-4 h-4 mr-2" />
                  <span class="sidebar-link-text">{gettext("Playlists")}</span>
                </h3>
                <nav class="space-y-1">
                  <.sidebar_link
                    href={~p"/playlists"}
                    current_page={@current_page}
                    page_id="library"
                    icon="hero-musical-note"
                    title={gettext("My Library")}
                  >
                    {gettext("My Library")}
                  </.sidebar_link>
                  <.sidebar_link
                    href={~p"/playlists/rules"}
                    current_page={@current_page}
                    page_id="rules"
                    icon="hero-adjustments-horizontal"
                    title={gettext("Rules")}
                  >
                    {gettext("Rules")}
                  </.sidebar_link>
                  <%= if PremiereEcouteCore.FeatureFlag.enabled?(:playlist_workflows, for: @current_user) do %>
                    <.sidebar_link
                      href={~p"/playlists/workflows"}
                      current_page={@current_page}
                      page_id="playlists_workflows"
                      title={gettext("Workflows")}
                      icon="hero-cog-6-tooth"
                    >
                      {gettext("Workflows")}
                    </.sidebar_link>
                  <% end %>
                </nav>
              </div>
            <% end %>
            
    <!-- Sessions section -->
            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:listening_sessions, for: @current_user) do %>
              <div class="mb-6">
                <h3 class="sidebar-section-title text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3 flex items-center">
                  <.icon name="hero-musical-note" class="w-4 h-4 mr-2" />
                  <span class="sidebar-link-text">{gettext("Sessions")}</span>
                </h3>
                <nav class="space-y-1">
                  <%= if @current_user.role in [:streamer, :admin] do %>
                    <.sidebar_link
                      title={gettext("My Sessions")}
                      href={~p"/sessions"}
                      current_page={@current_page}
                      page_id="my_sessions"
                      icon="hero-rectangle-stack"
                    >
                      {gettext("My Sessions")}
                    </.sidebar_link>

                    <.sidebar_link
                      href={~p"/retrospective/history"}
                      current_page={@current_page}
                      page_id="retrospective"
                      title={gettext("Retrospective")}
                      icon="hero-chart-bar"
                    >
                      {gettext("Retrospective")}
                    </.sidebar_link>
                  <% end %>

                  <.sidebar_link
                    href={~p"/retrospective/votes"}
                    current_page={@current_page}
                    page_id="votes"
                    title={gettext("My votes")}
                    icon="hero-heart"
                  >
                    {gettext("My votes")}
                  </.sidebar_link>
                </nav>
              </div>
            <% end %>
            
    <!-- Billboards section -->
            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:billboards, for: @current_user) do %>
              <div class="mb-6">
                <h3 class="sidebar-section-title text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3 flex items-center">
                  <.icon name="hero-chart-bar-square" class="w-4 h-4 mr-2" />
                  <span class="sidebar-link-text">{gettext("Billboards")}</span>
                </h3>
                <nav class="space-y-1">
                  <%= if @current_user.role in [:streamer, :admin] do %>
                    <.sidebar_link
                      href={~p"/billboards"}
                      current_page={@current_page}
                      title={gettext("My Billboards")}
                      page_id="billboards"
                      icon="hero-chart-bar-square"
                    >
                      {gettext("My Billboards")}
                    </.sidebar_link>
                  <% end %>
                  <.sidebar_link
                    href={~p"/billboards/submissions"}
                    current_page={@current_page}
                    page_id="submissions"
                    title={gettext("My Submissions")}
                    icon="hero-bookmark"
                  >
                    {gettext("My Submissions")}
                  </.sidebar_link>
                </nav>
              </div>
            <% end %>
            
    <!-- Festivals section -->
            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:festivals, for: @current_user) do %>
              <div class="mb-6">
                <h3 class="sidebar-section-title text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3 flex items-center">
                  <.icon name="hero-star" class="w-4 h-4 mr-2" />
                  <span class="sidebar-link-text">{gettext("Festivals")}</span>
                </h3>
                <nav class="space-y-1">
                  <%= if @current_user.role in [:streamer, :admin] do %>
                    <.sidebar_link
                      href={~p"/festivals/new"}
                      title={gettext("New Festival")}
                      current_page={@current_page}
                      page_id="festivals_new"
                      icon="hero-plus"
                    >
                      {gettext("New Festival")}
                    </.sidebar_link>
                  <% end %>
                </nav>
              </div>
            <% end %>
            
    <!-- Followed Channels section -->
            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:follow_channels, for: @current_user) do %>
              <%= if has_loaded_channels?(@current_user) && !Enum.empty?(@current_user.channels) do %>
                <div class="sidebar-followed-channels mb-6">
                  <h3 class="sidebar-section-title text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3 flex items-center">
                    <.icon name="hero-user-group" class="w-4 h-4 mr-2" />
                    <span class="sidebar-link-text">{gettext("Followed Channels")}</span>
                  </h3>
                  <nav class="space-y-1">
                    <%= for channel <- @current_user.channels |> Enum.take(10) do %>
                      <.sidebar_channel_link channel={channel} />
                    <% end %>

                    <%= if has_loaded_channels?(@current_user) && length(@current_user.channels) > 10 do %>
                      <.sidebar_link
                        href={~p"/users/follows"}
                        title={gettext("View all")}
                        current_page={@current_page}
                        page_id="all_follows"
                        icon="hero-ellipsis-horizontal"
                        class="text-sm"
                      >
                        {gettext("View all")} ({if has_loaded_channels?(@current_user),
                          do: length(@current_user.channels),
                          else: "..."})
                      </.sidebar_link>
                    <% end %>
                  </nav>
                </div>
              <% else %>
                <!-- Empty state for no followed channels -->
                <div class="sidebar-followed-channels mb-6">
                  <h3 class="sidebar-section-title text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3 flex items-center">
                    <.icon name="hero-user-group" class="w-4 h-4 mr-2" />
                    <span class="sidebar-link-text">{gettext("Followed Channels")}</span>
                  </h3>
                  <div class="text-sm text-gray-500 p-3 border rounded-lg" style="border-color: var(--color-dark-700);">
                    <p class="mb-2">{gettext("No followed channels yet")}</p>
                    <.link href={~p"/users/follows"} class="text-purple-400 hover:text-purple-300 underline">
                      {gettext("Discover streamers")}
                    </.link>
                  </div>
                </div>
              <% end %>
            <% end %>
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
  attr :title, :string, default: nil, doc: "tooltip text for the link"
  slot :inner_block, required: true

  def sidebar_link(assigns) do
    ~H"""
    <.link
      href={@href}
      title={@title}
      class={[
        "sidebar-link flex items-center px-3 py-2 text-base font-medium rounded-lg transition-colors",
        if @current_page == @page_id do
          "text-white" <> " " <> "bg-purple-600"
        else
          "text-gray-300 hover:text-white hover:bg-gray-800"
        end,
        @class
      ]}
    >
      <.icon name={@icon} class="icon w-5 h-5 mr-3" />
      <span class="sidebar-link-text">{render_slot(@inner_block)}</span>
    </.link>
    """
  end

  attr :channel, :map, required: true

  defp sidebar_channel_link(assigns) do
    ~H"""
    <div
      title={@channel.twitch.username || @channel.email}
      class="flex items-center px-3 py-2 text-base font-medium text-gray-300 hover:text-white hover:bg-gray-800 rounded-lg transition-colors cursor-pointer"
    >
      <div class="w-7 h-7 rounded-full bg-purple-600 border border-gray-700 flex items-center justify-center text-white font-semibold text-sm mr-3">
        {String.upcase(String.first(@channel.twitch.username || @channel.email))}
      </div>
      <span class="truncate">
        {@channel.twitch.username || @channel.email}
      </span>
    </div>
    """
  end

  defp has_loaded_channels?(nil), do: false
  defp has_loaded_channels?(%{channels: %Ecto.Association.NotLoaded{}}), do: false
  defp has_loaded_channels?(%{channels: _}), do: true
end
