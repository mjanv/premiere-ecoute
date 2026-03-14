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
        class="sidebar flex flex-col border-r fixed top-0 left-0 h-screen overflow-hidden z-40"
        style="background-color: var(--color-dark-900); border-color: var(--color-dark-800);"
      >
        <div class="flex-1 flex flex-col justify-center">
          <nav class="p-3 space-y-1">
            <.sidebar_link
              href={~p"/"}
              current_page={@current_page}
              page_id="home"
              icon="hero-home"
              title={gettext("Home")}
            >
              {gettext("Home")}
            </.sidebar_link>

            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:playlists, for: @current_user) do %>
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
            <% end %>

            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:listening_sessions, for: @current_user) do %>
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
            <% end %>

            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:collections, for: @current_user) do %>
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
            <% end %>

            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:billboards, for: @current_user) do %>
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
            <% end %>
          </nav>
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
      <.icon name={@icon} class="icon w-6 h-6 mr-3" />
      <span class="sidebar-link-text">{render_slot(@inner_block)}</span>
    </.link>
    """
  end
end
