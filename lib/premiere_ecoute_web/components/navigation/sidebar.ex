defmodule PremiereEcouteWeb.Components.Sidebar do
  @moduledoc """
  Left sidebar component with navigation sections for authenticated users.
  """

  use PremiereEcouteWeb, :html

  @doc """
  Renders the left sidebar with navigation sections.
  Only visible for authenticated users with appropriate permissions.
  """
  @spec left_sidebar(map()) :: Phoenix.LiveView.Rendered.t()
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
                  <.icon name="hero-microphone" class="w-4 h-4 mr-2" />
                  <span class="sidebar-link-text">{gettext("Playlists")}</span>
                </h3>
                <nav class="space-y-1">
                  <.sidebar_link
                    href={~p"/playlists"}
                    current_page={@current_page}
                    page_id="library"
                    icon="hero-inbox"
                    title={gettext("My Library")}
                  >
                    {gettext("My Library")}
                  </.sidebar_link>
                  <%= if @current_user.role in [:streamer, :admin] and PremiereEcouteCore.FeatureFlag.enabled?(:radio, for: @current_user) do %>
                    <.sidebar_link
                      href={~p"/radio/#{@current_user.username}"}
                      current_page={@current_page}
                      page_id="radio"
                      title={gettext("My Radio")}
                      icon="hero-radio"
                    >
                      {gettext("My Radio")}
                    </.sidebar_link>
                  <% end %>
                </nav>
              </div>
            <% end %>

    <!-- Sessions section -->
            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:listening_sessions, for: @current_user) do %>
              <div class="mb-6">
                <h3 class="sidebar-section-title text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3 flex items-center">
                  <.icon name="hero-fire" class="w-4 h-4 mr-2" />
                  <span class="sidebar-link-text">{gettext("Sessions")}</span>
                </h3>
                <nav class="space-y-1">
                  <%= if @current_user.role in [:streamer, :admin] do %>
                    <.sidebar_link
                      title={gettext("My Sessions")}
                      href={~p"/sessions"}
                      current_page={@current_page}
                      page_id="my_sessions"
                      icon="hero-tag"
                    >
                      {gettext("My Sessions")}
                    </.sidebar_link>

                    <.sidebar_link
                      href={~p"/retrospective/history"}
                      current_page={@current_page}
                      page_id="retrospective"
                      title={gettext("Retrospective")}
                      icon="hero-magnifying-glass"
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
                  <.sidebar_link
                    href={~p"/retrospective/tops"}
                    current_page={@current_page}
                    page_id="tops"
                    title={gettext("My tops")}
                    icon="hero-trophy"
                  >
                    {gettext("My tops")}
                  </.sidebar_link>
                </nav>
              </div>
            <% end %>

    <!-- Collections section -->
            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:collections, for: @current_user) do %>
              <div class="mb-6">
                <h3 class="sidebar-section-title text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3 flex items-center">
                  <.icon name="hero-shopping-bag" class="w-4 h-4 mr-2" />
                  <span class="sidebar-link-text">{gettext("Collections")}</span>
                </h3>
                <nav class="space-y-1">
                  <%= if @current_user.role in [:streamer, :admin] do %>
                    <.sidebar_link
                      href={~p"/collections"}
                      current_page={@current_page}
                      page_id="collections"
                      title={gettext("Collections")}
                      icon="hero-rectangle-stack"
                    >
                      {gettext("Collections")}
                    </.sidebar_link>
                  <% end %>
                </nav>
              </div>
            <% end %>

    <!-- Billboards section -->
            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:billboards, for: @current_user) do %>
              <div class="mb-6">
                <h3 class="sidebar-section-title text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3 flex items-center">
                  <.icon name="hero-newspaper" class="w-4 h-4 mr-2" />
                  <span class="sidebar-link-text">{gettext("Billboards")}</span>
                </h3>
                <nav class="space-y-1">
                  <%= if @current_user.role in [:streamer, :admin] do %>
                    <.sidebar_link
                      href={~p"/billboards"}
                      current_page={@current_page}
                      title={gettext("My Billboards")}
                      page_id="billboards"
                      icon="hero-paper-clip"
                    >
                      {gettext("My Billboards")}
                    </.sidebar_link>
                  <% end %>
                  <.sidebar_link
                    href={~p"/billboards/submissions"}
                    current_page={@current_page}
                    page_id="submissions"
                    title={gettext("My Submissions")}
                    icon="hero-pencil"
                  >
                    {gettext("My Submissions")}
                  </.sidebar_link>
                </nav>
              </div>
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
  @spec sidebar_link(map()) :: Phoenix.LiveView.Rendered.t()
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
end
