defmodule PremiereEcouteWeb.HomeComponents do
  @moduledoc """
  Components specific to the HomeLive page.

  Provides album squares, radio track cards, session rows, and the scroll carousel wrapper.
  """

  use Phoenix.Component

  use PremiereEcouteWeb, :verified_routes

  alias PremiereEcoute.Sessions.ListeningSession

  @doc """
  Renders a scrollable carousel with prev/next round buttons driven by the ScrollCarousel hook.

  ## Slots

    * `:items` – the carousel items

  ## Examples

      <.scroll_carousel id="album-carousel">
        <div class="flex-shrink-0 w-36 h-36">...</div>
      </.scroll_carousel>
  """
  attr :id, :string, required: true
  slot :inner_block, required: true

  def scroll_carousel(assigns) do
    ~H"""
    <div class="relative" id={@id} phx-hook="ScrollCarousel">
      <button
        data-carousel-prev
        class="absolute -left-4 top-1/2 -translate-y-1/2 z-10 w-8 h-8 rounded-full bg-white/40 hover:bg-white/55 border border-white/40 flex items-center justify-center transition-all opacity-0 pointer-events-none"
      >
        <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
      </button>

      <div data-carousel-track class="flex gap-4 overflow-x-hidden scroll-smooth">
        {render_slot(@inner_block)}
      </div>

      <button
        data-carousel-next
        class="absolute -right-4 top-1/2 -translate-y-1/2 z-10 w-8 h-8 rounded-full bg-white/40 hover:bg-white/55 border border-white/40 flex items-center justify-center transition-all"
      >
        <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
        </svg>
      </button>
    </div>
    """
  end

  @doc """
  Renders a square album card with a cover image and a hover overlay showing name and artist.
  """
  attr :album, :map, required: true

  def album_square(assigns) do
    ~H"""
    <div class="relative group flex-shrink-0 w-36 h-36 rounded-lg overflow-hidden shadow-lg">
      <%= if @album.cover_url do %>
        <img src={@album.cover_url} alt={@album.name} class="w-full h-full object-cover" loading="lazy" />
      <% else %>
        <div class="w-full h-full bg-gradient-to-br from-indigo-900 to-purple-900 flex items-center justify-center">
          <svg class="w-10 h-10 text-white/40" fill="currentColor" viewBox="0 0 20 20">
            <path d="M18 3a1 1 0 00-1.196-.98L3 6.687a1 1 0 000 1.838l4.49 1.497L9.5 14.75a1 1 0 001.838 0L15.014 10H18a1 1 0 001-1V4a1 1 0 00-1-1z" />
          </svg>
        </div>
      <% end %>
      <div class="absolute inset-0 bg-black/70 opacity-0 group-hover:opacity-100 transition-opacity duration-200 flex flex-col justify-end p-2">
        <p class="text-white text-xs font-semibold leading-tight truncate">{@album.name}</p>
        <p class="text-slate-300 text-xs truncate">{@album.artist}</p>
      </div>
    </div>
    """
  end

  @doc """
  Renders a compact rectangular card for a radio track, showing name, artist, and time.
  """
  attr :track, :map, required: true

  def radio_track_card(assigns) do
    ~H"""
    <div class="relative flex-shrink-0 w-36 h-10 rounded-lg overflow-hidden border border-white/10 shadow-lg bg-white/5 flex flex-col justify-center px-2">
      <p class="text-white text-xs font-semibold leading-tight truncate">{@track.name}</p>
      <p class="text-slate-400 text-xs truncate">{@track.artist} · {Calendar.strftime(@track.started_at, "%H:%M")}</p>
    </div>
    """
  end

  @doc """
  Renders a single row in the upcoming sessions panel.
  Active sessions are highlighted with a green left border.
  """
  attr :session, :map, required: true

  def session_row(assigns) do
    ~H"""
    <.link href={~p"/sessions/#{@session.id}"} class="group block">
      <div class={[
        "flex items-center gap-4 px-4 py-3 hover:bg-white/5 transition-all border-l-2",
        if(@session.status == :active, do: "border-l-green-500", else: "border-l-transparent")
      ]}>
        <div class="flex-shrink-0 w-12 h-12 rounded-lg overflow-hidden">
          <%= if @session.album && @session.album.cover_url do %>
            <img
              src={@session.album.cover_url}
              alt={ListeningSession.title(@session)}
              class="w-full h-full object-cover"
              loading="lazy"
            />
          <% else %>
            <div class="w-full h-full bg-gradient-to-br from-indigo-900 to-purple-900 flex items-center justify-center">
              <svg class="w-5 h-5 text-white/40" fill="currentColor" viewBox="0 0 20 20">
                <path d="M18 3a1 1 0 00-1.196-.98L3 6.687a1 1 0 000 1.838l4.49 1.497L9.5 14.75a1 1 0 001.838 0L15.014 10H18a1 1 0 001-1V4a1 1 0 00-1-1z" />
              </svg>
            </div>
          <% end %>
        </div>

        <div class="flex-1 min-w-0">
          <p class={[
            "text-sm font-semibold truncate",
            if(@session.status == :active, do: "text-white", else: "text-slate-300")
          ]}>
            {ListeningSession.title(@session)}
          </p>
          <p class="text-slate-400 text-xs truncate">{ListeningSession.artist(@session)}</p>
        </div>

        <span class={[
          "flex-shrink-0 text-xs px-2 py-1 rounded",
          case @session.status do
            :active -> "bg-green-600/20 text-green-400"
            :preparing -> "bg-indigo-600/20 text-indigo-400"
          end
        ]}>
          {case @session.status do
            :active -> "Live"
            :preparing -> "Ready"
          end}
        </span>

        <svg
          class="w-4 h-4 text-slate-600 group-hover:text-slate-400 transition-colors flex-shrink-0"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
        </svg>
      </div>
    </.link>
    """
  end
end
