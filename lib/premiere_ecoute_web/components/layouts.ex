defmodule PremiereEcouteWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  use PremiereEcouteWeb, :html

  import PremiereEcouteWeb.Components.Header
  import PremiereEcouteWeb.Components.Sidebar

  embed_templates "layouts/*"

  @doc """
  Renders the app layout for our streaming dashboard

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 flex flex-col">
      <.app_header current_user={(@current_scope && Map.get(@current_scope, :user)) || nil} current_scope={@current_scope} />
      
    <!-- AIDEV-NOTE: Spotify connection notification for streamers -->
      <%= if @current_scope && Map.get(@current_scope, :user) && Map.get(@current_scope, :user).role in [:streamer, :admin] && needs_spotify_connection?(Map.get(@current_scope, :user)) do %>
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
      
    <!-- AIDEV-NOTE: Layout with left sidebar for authenticated users -->
      <div class="flex flex-1">
        <.left_sidebar
          current_user={(@current_scope && Map.get(@current_scope, :user)) || nil}
          current_scope={@current_scope}
          current_page={assigns[:current_page]}
        />
        
    <!-- Main content area -->
        <main class="flex-1">
          {render_slot(@inner_block)}
        </main>
      </div>
      
    <!-- Footer - spans full width under both sidebar and content -->
      <footer class="py-4 px-6 mt-auto" style="border-top: 1px solid var(--color-dark-800); background-color: var(--color-dark-900);">
        <div class="max-w-5xl mx-auto text-center">
          <div class="flex justify-center items-center space-x-3">
            <.link
              href={~p"/changelog"}
              class="text-sm font-medium transition-colors hover:text-white"
              style="color: var(--color-dark-300);"
            >
              {gettext("Changelog")}
            </.link>
            <span class="text-sm" style="color: var(--color-dark-500);">&bull;</span>
            <.link
              href={~p"/legal/privacy"}
              class="text-sm font-medium transition-colors hover:text-white"
              style="color: var(--color-dark-300);"
            >
              {gettext("Privacy")}
            </.link>
            <span class="text-sm" style="color: var(--color-dark-500);">&bull;</span>
            <.link
              href={~p"/legal/cookies"}
              class="text-sm font-medium transition-colors hover:text-white"
              style="color: var(--color-dark-300);"
            >
              {gettext("Cookies")}
            </.link>
            <span class="text-sm" style="color: var(--color-dark-500);">&bull;</span>
            <.link
              href={~p"/legal/terms"}
              class="text-sm font-medium transition-colors hover:text-white"
              style="color: var(--color-dark-300);"
            >
              {gettext("Terms")}
            </.link>
            <span class="text-sm" style="color: var(--color-dark-500);">&bull;</span>
            <.link
              href={~p"/legal/contact"}
              class="text-sm font-medium transition-colors hover:text-white"
              style="color: var(--color-dark-300);"
            >
              {gettext("Contact")}
            </.link>
          </div>
        </div>
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  # AIDEV-NOTE: Helper function to check if user needs Spotify connection
  defp needs_spotify_connection?(nil), do: false

  defp needs_spotify_connection?(user) do
    user.spotify_access_token == nil || user.spotify_refresh_token == nil
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
