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
            <.sidebar_link href={~p"/"} page={@current_page} page_id="home" icon="hero-home">{gettext("Home")}</.sidebar_link>

            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:discography, for: @current_user) do %>
              <%= if @current_user.role in [:streamer, :admin] do %>
                <.sidebar_link
                  href={~p"/discography"}
                  page={@current_page}
                  page_id="discography"
                  icon="hero-ticket"
                >
                  {gettext("Discography")}
                </.sidebar_link>
              <% end %>
            <% end %>

            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:playlists, for: @current_user) do %>
              <%= if @current_user.role in [:streamer, :admin] do %>
                <.sidebar_link
                  href={~p"/playlists"}
                  page={@current_page}
                  page_id="library"
                  icon="hero-inbox"
                >
                  {gettext("Playlists")}
                </.sidebar_link>
              <% end %>
            <% end %>

            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:collections, for: @current_user) do %>
              <%= if @current_user.role in [:streamer, :admin] do %>
                <.sidebar_link
                  href={~p"/collections"}
                  page={@current_page}
                  page_id="collections"
                  icon="hero-squares-2x2"
                >
                  {gettext("Collections")}
                </.sidebar_link>
              <% end %>
            <% end %>

            <%= if PremiereEcouteCore.FeatureFlag.enabled?(:listening_sessions, for: @current_user) do %>
              <%= if @current_user.role in [:streamer, :admin] do %>
                <.sidebar_link
                  href={~p"/sessions"}
                  page={@current_page}
                  page_id="sessions"
                  icon="hero-tag"
                >
                  {gettext("Sessions")}
                </.sidebar_link>
                <.sidebar_link
                  href={~p"/sessions/retrospective"}
                  page={@current_page}
                  page_id="retrospective"
                  icon="hero-magnifying-glass"
                >
                  {gettext("Retrospective")}
                </.sidebar_link>
              <% end %>
              <.sidebar_link
                href={~p"/sessions/retrospective/votes"}
                page={@current_page}
                page_id="votes"
                icon="hero-heart"
              >
                {gettext("History")}
              </.sidebar_link>
              <.sidebar_link
                href={~p"/sessions/retrospective/tops"}
                page={@current_page}
                page_id="tops"
                icon="hero-trophy"
              >
                {gettext("Top Charts")}
              </.sidebar_link>
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
  attr :page, :string, default: nil
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
        if @page == @page_id do
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
