defmodule PremiereEcouteWeb.Billboards.DisplayLive do
  @moduledoc """
  LiveView for displaying generated billboard results.

  Shows the ranked tracks, artists, and years based on submitted playlists.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Billboards
  alias PremiereEcoute.Billboards.Billboard
  alias PremiereEcouteCore.Cache
  alias PremiereEcouteWeb.Layouts

  @impl true
  def mount(%{"id" => billboard_id}, _session, socket) do
    case Billboards.get_billboard(billboard_id) do
      nil ->
        socket
        |> put_flash(:error, "Billboard not found")
        |> redirect(to: ~p"/")
        |> then(fn socket -> {:ok, socket} end)

      %Billboard{} = billboard ->
        current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

        if current_user.id == billboard.user_id do
          socket =
            socket
            |> assign(:page_title, "#{billboard.title} - Results")
            |> assign(:billboard, billboard)
            |> assign(:loading, true)
            |> assign(:results, nil)
            |> assign(:error, nil)
            |> assign(:active_tab, "tracks")

          # AIDEV-NOTE: Check cache first, then generate if needed
          send(self(), :load_billboard)

          {:ok, socket}
        else
          socket
          |> put_flash(:error, "You don't have permission to access this billboard")
          |> redirect(to: ~p"/")
          |> then(fn socket -> {:ok, socket} end)
        end
    end
  end

  @impl true
  def handle_info(:load_billboard, socket) do
    billboard = socket.assigns.billboard
    cache_key = "billboard_#{billboard.billboard_id}"

    # AIDEV-NOTE: Try loading from cache first
    case Cache.get(:billboards, cache_key) do
      {:ok, cached_results} when not is_nil(cached_results) ->
        socket
        |> assign(:loading, false)
        |> assign(:results, cached_results)
        |> assign(:error, nil)
        |> then(fn socket -> {:noreply, socket} end)

      _ ->
        # Not in cache, generate it
        send(self(), :generate_billboard)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:generate_billboard, socket) do
    billboard = socket.assigns.billboard

    case Billboards.generate_billboard_display(billboard) do
      {:ok, results} ->
        # AIDEV-NOTE: Store in cache for future use
        cache_key = "billboard_#{billboard.billboard_id}"
        Cache.put(:billboards, cache_key, results)

        socket
        |> assign(:loading, false)
        |> assign(:results, results)
        |> assign(:error, nil)
        |> then(fn socket -> {:noreply, socket} end)

      {:error, error} ->
        error_message =
          case error do
            :no_submissions -> "No submissions available to generate billboard"
            _ -> "Failed to generate billboard. Please try again."
          end

        socket
        |> assign(:loading, false)
        |> assign(:error, error_message)
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  # Component functions

  defp tracks_table(assigns) do
    ~H"""
    <div class="bg-gradient-to-br from-slate-50/6 to-slate-100/3 border border-white/10 rounded-2xl shadow-xl backdrop-blur-sm">
      <div class="p-6">
        <h3 class="text-2xl font-semibold text-white mb-6 flex items-center">
          <svg class="w-6 h-6 text-purple-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"
            />
          </svg>
          Top Tracks
        </h3>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="border-b border-white/10">
                <th class="text-left py-3 px-4 text-sm font-semibold text-slate-300 w-16">Rank</th>
                <th class="text-left py-3 px-4 text-sm font-semibold text-slate-300">Track</th>
                <th class="text-left py-3 px-4 text-sm font-semibold text-slate-300">Artist</th>
                <th class="text-left py-3 px-4 text-sm font-semibold text-slate-300 w-20">Count</th>
              </tr>
            </thead>
            <tbody>
              <%= for track <- Enum.take(@tracks, 50) do %>
                <tr class="border-b border-white/5 hover:bg-white/5 transition-colors">
                  <td class="py-3 px-4 text-sm">
                    <span class="inline-flex items-center justify-center w-8 h-8 rounded-full bg-purple-600/20 text-purple-300 font-bold text-xs">
                      {track.rank}
                    </span>
                  </td>
                  <td class="py-3 px-4 text-sm text-white font-medium">
                    {track.track.name}
                  </td>
                  <td class="py-3 px-4 text-sm text-slate-300">
                    {track.track.artist}
                  </td>
                  <td class="py-3 px-4 text-sm">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-600/20 text-green-300">
                      {track.count}
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp artists_table(assigns) do
    ~H"""
    <div class="bg-gradient-to-br from-slate-50/6 to-slate-100/3 border border-white/10 rounded-2xl shadow-xl backdrop-blur-sm">
      <div class="p-6">
        <h3 class="text-2xl font-semibold text-white mb-6 flex items-center">
          <svg class="w-6 h-6 text-purple-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
            />
          </svg>
          Top Artists
        </h3>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="border-b border-white/10">
                <th class="text-left py-3 px-4 text-sm font-semibold text-slate-300 w-16">Rank</th>
                <th class="text-left py-3 px-4 text-sm font-semibold text-slate-300">Artist</th>
                <th class="text-left py-3 px-4 text-sm font-semibold text-slate-300 w-32">Total Points</th>
                <th class="text-left py-3 px-4 text-sm font-semibold text-slate-300 w-32">Unique Tracks</th>
              </tr>
            </thead>
            <tbody>
              <%= for artist <- Enum.take(@artists, 30) do %>
                <tr class="border-b border-white/5 hover:bg-white/5 transition-colors">
                  <td class="py-3 px-4 text-sm">
                    <span class="inline-flex items-center justify-center w-8 h-8 rounded-full bg-purple-600/20 text-purple-300 font-bold text-xs">
                      {artist.rank}
                    </span>
                  </td>
                  <td class="py-3 px-4 text-sm text-white font-medium">
                    {artist.artist}
                  </td>
                  <td class="py-3 px-4 text-sm">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-600/20 text-blue-300">
                      {artist.count}
                    </span>
                  </td>
                  <td class="py-3 px-4 text-sm">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-600/20 text-green-300">
                      {artist.track_count}
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp years_table(assigns) do
    ~H"""
    <div class="bg-gradient-to-br from-slate-50/6 to-slate-100/3 border border-white/10 rounded-2xl shadow-xl backdrop-blur-sm">
      <div class="p-6">
        <h3 class="text-2xl font-semibold text-white mb-6 flex items-center">
          <svg class="w-6 h-6 text-purple-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
          Top Years
        </h3>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="border-b border-white/10">
                <th class="text-left py-3 px-4 text-sm font-semibold text-slate-300 w-16">Rank</th>
                <th class="text-left py-3 px-4 text-sm font-semibold text-slate-300">Year</th>
                <th class="text-left py-3 px-4 text-sm font-semibold text-slate-300 w-32">Total Points</th>
                <th class="text-left py-3 px-4 text-sm font-semibold text-slate-300 w-32">Unique Tracks</th>
              </tr>
            </thead>
            <tbody>
              <%= for year <- Enum.take(@years, 20) do %>
                <tr class="border-b border-white/5 hover:bg-white/5 transition-colors">
                  <td class="py-3 px-4 text-sm">
                    <span class="inline-flex items-center justify-center w-8 h-8 rounded-full bg-purple-600/20 text-purple-300 font-bold text-xs">
                      {year.rank}
                    </span>
                  </td>
                  <td class="py-3 px-4 text-sm text-white font-medium">
                    {year.year}
                  </td>
                  <td class="py-3 px-4 text-sm">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-600/20 text-blue-300">
                      {year.count}
                    </span>
                  </td>
                  <td class="py-3 px-4 text-sm">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-600/20 text-green-300">
                      {year.track_count}
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp tab_class(active_tab, tab) do
    base = "flex-1 flex items-center justify-center px-4 py-2 text-sm font-medium rounded-md transition-colors"

    if active_tab == tab do
      base <> " bg-white/10 text-white shadow-sm"
    else
      base <> " text-slate-400 hover:text-white hover:bg-white/5"
    end
  end

  defp badge_class(active_tab, tab) do
    base = "ml-2 px-2 py-0.5 rounded-full text-xs font-medium"

    if active_tab == tab do
      base <> " bg-purple-600/30 text-purple-200"
    else
      base <> " bg-white/10 text-slate-400"
    end
  end
end
