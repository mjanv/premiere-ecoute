defmodule PremiereEcouteWeb.Components.Images do
  @moduledoc """
  Image components that route cover art through the local proxy.
  """

  use Phoenix.Component

  use PremiereEcouteWeb, :verified_routes

  @doc """
  Renders a cover image routed through the local image proxy.

  Rewrites the `src` URL to `/img?url=<encoded>` so browsers never
  hit provider CDNs directly.

  ## Attributes

    * `src` - Original image URL (Spotify/Deezer/Tidal CDN). Nil renders nothing.
    * `alt` - Alt text for the image
    * `class` - CSS classes passed through to the `<img>` tag
  """
  attr :src, :string, default: nil
  attr :alt, :string, default: ""
  attr :class, :any, default: nil
  attr :rest, :global

  def cover(assigns) do
    assigns = assign(assigns, :proxy_src, proxy_url(assigns.src))

    ~H"""
    <%= if @proxy_src do %>
      <img src={@proxy_src} alt={@alt} class={@class} loading="lazy" {@rest} />
    <% end %>
    """
  end

  @doc "Returns the proxy URL for a given image source, or nil if src is nil."
  def proxy_url(nil), do: nil
  def proxy_url(src), do: ~p"/img?url=#{src}"
end
