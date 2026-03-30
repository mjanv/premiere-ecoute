defmodule PremiereEcouteWeb.Wantlist.WantlistLive do
  @moduledoc """
  Wantlist management page.

  Displays all items saved in the current user's wantlist, grouped by type
  (albums, tracks, artists). Allows removing individual items.
  """

  use PremiereEcouteWeb, :live_view

  use Gettext, backend: PremiereEcoute.Gettext

  alias PremiereEcoute.Wantlists

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    wantlist = Wantlists.get_wantlist(user.id)
    items = if wantlist, do: wantlist.items, else: []

    {:ok,
     socket
     |> assign(:view, :grid)
     |> assign(:provider, :spotify)
     |> assign_items(items)}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_view", %{"mode" => mode}, socket) when mode in ["grid", "list"] do
    {:noreply, assign(socket, :view, String.to_existing_atom(mode))}
  end

  @impl true
  def handle_event("set_provider", %{"name" => name}, socket) when name in ["spotify", "deezer", "tidal"] do
    {:noreply, assign(socket, :provider, String.to_existing_atom(name))}
  end

  @impl true
  def handle_event("remove_item", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    item_id = String.to_integer(id)

    case Wantlists.remove_item(user.id, item_id) do
      {:ok, _} ->
        remaining = Enum.reject(socket.assigns.items, &(&1.id == item_id))

        {:noreply,
         socket
         |> assign_items(remaining)
         |> put_flash(:info, gettext("Item removed from wantlist"))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, gettext("Item not found"))}
    end
  end

  attr :item_id, :integer, required: true
  attr :name, :string, required: true
  attr :subtitle, :string, default: nil
  attr :cover_url, :string, default: nil
  attr :navigate, :string, required: true
  attr :provider_url, :string, default: nil
  attr :provider, :atom, required: true
  attr :view, :atom, required: true

  def wantlist_media_card(%{view: :grid} = assigns) do
    ~H"""
    <div class="group relative rounded-xl overflow-hidden border border-white/10 bg-white/5 hover:border-purple-400/40 transition-all">
      <.link navigate={@navigate} class="block">
        <%= if @cover_url do %>
          <img src={@cover_url} alt={@name} class="w-full aspect-square object-cover" loading="lazy" />
        <% else %>
          <div class="w-full aspect-square bg-gradient-to-br from-indigo-900 to-purple-900 flex items-center justify-center">
            <svg class="w-10 h-10 text-white/30" fill="currentColor" viewBox="0 0 20 20">
              <path d="M18 3a1 1 0 00-1.196-.98L3 6.687a1 1 0 000 1.838l4.49 1.497L9.5 14.75a1 1 0 001.838 0L15.014 10H18a1 1 0 001-1V4a1 1 0 00-1-1z" />
            </svg>
          </div>
        <% end %>
        <div class="px-3 py-2">
          <p class="text-white text-sm font-semibold truncate">{@name}</p>
          <p class="text-slate-400 text-xs truncate">{@subtitle}</p>
        </div>
      </.link>
      <%= if @provider_url do %>
        <a
          href={@provider_url}
          target="_blank"
          rel="noopener"
          class="absolute bottom-10 left-2 w-7 h-7 rounded-full bg-black/60 hover:bg-black/80 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all"
          title={to_string(@provider)}
        >
          <.provider_icon provider={@provider} class="w-3.5 h-3.5 text-white" />
        </a>
      <% end %>
      <button
        phx-click="remove_item"
        phx-value-id={@item_id}
        data-confirm={gettext("Remove from wantlist?")}
        class="absolute top-2 right-2 w-7 h-7 rounded-full bg-black/60 hover:bg-red-900/70 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all"
        title={gettext("Remove")}
      >
        <svg class="w-3.5 h-3.5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
    """
  end

  def wantlist_media_card(%{view: :list} = assigns) do
    ~H"""
    <div class="group flex items-center gap-4 px-4 py-3 rounded-xl border border-white/10 bg-white/5 hover:border-purple-400/40 transition-all">
      <.link navigate={@navigate} class="flex items-center gap-4 flex-1 min-w-0">
        <%= if @cover_url do %>
          <img src={@cover_url} alt={@name} class="w-10 h-10 rounded object-cover shrink-0" loading="lazy" />
        <% else %>
          <div class="w-10 h-10 rounded bg-gradient-to-br from-indigo-900 to-purple-900 shrink-0 flex items-center justify-center">
            <svg class="w-4 h-4 text-white/30" fill="currentColor" viewBox="0 0 20 20">
              <path d="M18 3a1 1 0 00-1.196-.98L3 6.687a1 1 0 000 1.838l4.49 1.497L9.5 14.75a1 1 0 001.838 0L15.014 10H18a1 1 0 001-1V4a1 1 0 00-1-1z" />
            </svg>
          </div>
        <% end %>
        <div class="min-w-0">
          <p class="text-white text-sm font-medium truncate">{@name}</p>
          <p class="text-slate-400 text-xs truncate">{@subtitle}</p>
        </div>
      </.link>
      <%= if @provider_url do %>
        <a
          href={@provider_url}
          target="_blank"
          rel="noopener"
          class="shrink-0 w-7 h-7 rounded-full bg-white/5 hover:bg-white/15 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all"
          title={to_string(@provider)}
        >
          <.provider_icon provider={@provider} class="w-3.5 h-3.5 text-slate-300" />
        </a>
      <% end %>
      <button
        phx-click="remove_item"
        phx-value-id={@item_id}
        data-confirm={gettext("Remove from wantlist?")}
        class="shrink-0 w-7 h-7 rounded-full hover:bg-red-900/50 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all"
        title={gettext("Remove")}
      >
        <svg class="w-3.5 h-3.5 text-slate-500 hover:text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
    """
  end

  attr :provider, :atom, required: true
  attr :class, :string, default: "w-4 h-4"

  def provider_icon(%{provider: :spotify} = assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" fill="currentColor">
      <path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z" />
    </svg>
    """
  end

  def provider_icon(%{provider: :deezer} = assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 120 120" fill="currentColor">
      <path d="M101.19 18.41c1.12-6.47 2.75-10.54 4.57-10.55 3.38.01 6.13 14.12 6.13 31.54s-2.75 31.54-6.13 31.54c-1.39 0-2.67-2.4-3.7-6.42-1.63 14.71-5.01 24.82-8.93 24.82-3.03 0-5.75-6.07-7.58-15.65-1.25 18.22-4.38 31.14-8.05 31.14-2.3 0-4.4-5.12-5.95-13.46-1.87 17.21-6.18 29.28-11.22 29.28s-9.36-12.06-11.22-29.28c-1.54 8.34-3.64 13.46-5.95 13.46-3.67 0-6.8-12.93-8.05-31.14-1.83 9.58-4.54 15.65-7.58 15.65-3.91 0-7.3-10.11-8.93-24.82-1.02 4.03-2.31 6.42-3.7 6.42-3.39 0-6.13-14.12-6.13-31.54S11.51 7.86 14.9 7.86c1.82 0 3.44 4.08 4.57 10.55C21.28 7.25 24.21 0 27.53 0c3.94 0 7.35 10.26 8.97 25.15C38.08 14.31 40.48 7.4 43.16 7.4c3.76 0 6.96 13.59 8.15 32.55 2.23-9.72 5.46-15.82 9.03-15.82s6.8 6.1 9.02 15.82C70.55 20.99 73.74 7.4 77.51 7.4c2.68 0 5.07 6.91 6.66 17.75C85.78 10.26 89.2 0 93.13 0c3.31 0 6.25 7.26 8.06 18.41z" />
    </svg>
    """
  end

  def provider_icon(%{provider: :tidal} = assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 512 512" fill="currentColor">
      <path d="M256 170.667L341.333 256 256 341.333 170.667 256zM85.333 256L170.667 341.333 256 256 170.667 170.667zM341.333 170.667L426.667 256 341.333 341.333 256 256zM170.667 85.333L256 170.667 170.667 256 85.333 170.667zM341.333 85.333L426.667 170.667 341.333 256 256 170.667z" />
    </svg>
    """
  end

  defp assign_items(socket, items) do
    album_items = Enum.filter(items, &(&1.type == :album))
    track_items = Enum.filter(items, &(&1.type == :track))
    artist_items = Enum.filter(items, &(&1.type == :artist))

    socket
    |> assign(:items, items)
    |> assign(:album_items, album_items)
    |> assign(:album_count, length(album_items))
    |> assign(:track_items, track_items)
    |> assign(:track_count, length(track_items))
    |> assign(:artist_items, artist_items)
    |> assign(:artist_count, length(artist_items))
  end
end
