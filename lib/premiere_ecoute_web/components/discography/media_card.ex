defmodule PremiereEcouteWeb.Components.MediaCard do
  @moduledoc """
  Square image grid card with hover zoom, optional badge, and text below.

  Used for albums, artists, singles, and playlists in grid listings.
  """

  use Phoenix.Component

  @doc """
  Renders a square image card for grid listings.

  ## Examples

      <.media_card
        src={album.cover_url}
        alt={album.name}
        title={album.name}
        subtitle={album.artist}
        navigate={~p"/discography/albums/\#{album.slug}"}
      />

      <.media_card
        src={artist_image_url}
        alt={artist.name}
        title={artist.name}
        shape="circle"
        navigate={~p"/discography/artists/\#{artist.slug}"}
      >
        <:badge>3</:badge>
      </.media_card>
  """
  attr :src, :string, default: nil, doc: "Cover image URL"
  attr :alt, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :navigate, :string, default: nil, doc: "Route for .link navigate"
  attr :href, :string, default: nil, doc: "External href for .link"
  attr :shape, :string, default: "square", values: ~w(square circle)
  attr :placeholder_class, :string, default: nil, doc: "Classes for the placeholder div when no src"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :badge, doc: "Small overlay badge shown bottom-right on the image"
  slot :overlay, doc: "Full overlay content shown on hover (replaces default zoom)"

  def media_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      href={@href}
      class={["group block", @class]}
      {@rest}
    >
      <div class={[
        "relative aspect-square overflow-hidden shadow-lg mb-3",
        if(@shape == "circle", do: "rounded-full", else: "rounded-lg")
      ]}>
        <%= if @src do %>
          <img
            src={@src}
            alt={@alt}
            class="w-full h-full object-cover transition-transform duration-300 group-hover:scale-105"
            loading="lazy"
          />
        <% else %>
          <div class={[
            "w-full h-full flex items-center justify-center",
            @placeholder_class || "bg-neutral/50"
          ]}>
            <slot />
          </div>
        <% end %>

        <%= if @badge != [] do %>
          <div class="absolute bottom-2 right-2 px-2 py-0.5 rounded-full bg-black/70 text-white text-xs font-medium flex items-center gap-1">
            {render_slot(@badge)}
          </div>
        <% end %>

        <%= if @overlay != [] do %>
          <div class="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
            {render_slot(@overlay)}
          </div>
        <% end %>
      </div>

      <p class="text-sm font-semibold truncate group-hover:text-primary transition-colors">
        {@title}
      </p>
      <p :if={@subtitle} class="text-xs text-base-content/50 truncate mt-0.5">
        {@subtitle}
      </p>
    </.link>
    """
  end
end
