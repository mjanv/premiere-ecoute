defmodule PremiereEcouteWeb.Components.DeezerWidget do
  @moduledoc """
  Deezer embed widget component.

  Renders an embedded Deezer player for albums, playlists, tracks, or artists
  using the official Deezer widget iframe API.

  ## Usage

      <.deezer_widget type="album" deezer_id="302127" />

      <.deezer_widget type="track" deezer_id="3135556" size="sm" />

      <.deezer_widget
        type="playlist"
        deezer_id="908622995"
        size="lg"
        theme="dark"
        color="EF6C00"
        show_tracklist={true}
      />
  """

  use Phoenix.Component

  # AIDEV-NOTE: Deezer widget base URL — theme, type, and id are path segments; options are query params
  @deezer_widget_base "https://widget.deezer.com/widget"

  @doc """
  Renders an embedded Deezer player widget via iframe.

  The widget is provided by Deezer's official embed API and supports
  albums, playlists, tracks, and artists with configurable size, theme,
  accent color, and tracklist visibility.

  ## Attributes

    * `type` - Resource type: "album", "playlist", "track", "artist" (required)
    * `deezer_id` - Deezer resource ID as a string or integer (required)
    * `size` - Widget preset size: "sm", "md", "lg", "full" (default: "md")
    * `theme` - Color theme: "dark", "light", "auto" (default: "dark")
    * `color` - Accent hex color without `#`, e.g. `"EF6C00"` (default: `"EF6C00"`)
    * `autoplay` - Start playback automatically (default: `false`)
    * `show_tracklist` - Show the tracklist panel (default: `true`)
    * `class` - Additional CSS classes on the wrapper `<div>`

  ## Size presets

  | size   | height  | notes                                    |
  |--------|---------|------------------------------------------|
  | `sm`   | 92px    | Minimal player bar; best for tracks      |
  | `md`   | 300px   | Standard embed with tracklist            |
  | `lg`   | 450px   | Larger embed; shows more tracks          |
  | `full` | 100vh   | Takes full viewport height               |

  Width always fills the parent container.

  ## Examples

      <.deezer_widget type="album" deezer_id="302127" />

      <.deezer_widget type="track" deezer_id="3135556" size="sm" />

      <.deezer_widget
        type="playlist"
        deezer_id="908622995"
        theme="light"
        color="4B0082"
        size="lg"
        show_tracklist={false}
      />
  """
  @spec deezer_widget(map()) :: Phoenix.LiveView.Rendered.t()
  attr :type, :string,
    required: true,
    values: ~w(album playlist track artist),
    doc: "Deezer resource type"

  attr :deezer_id, :any,
    required: true,
    doc: "Deezer resource ID (string or integer)"

  attr :size, :string,
    default: "md",
    values: ~w(sm md lg full),
    doc: "Widget size preset"

  attr :theme, :string,
    default: "dark",
    values: ~w(dark light auto),
    doc: "Iframe color theme"

  attr :color, :string,
    default: "EF6C00",
    doc: "Accent hex color without '#' (default Deezer orange)"

  attr :autoplay, :boolean,
    default: false,
    doc: "Auto-start playback on load"

  attr :show_tracklist, :boolean,
    default: true,
    doc: "Show the tracklist panel inside the widget"

  attr :class, :string, default: nil
  attr :rest, :global

  def deezer_widget(assigns) do
    ~H"""
    <div
      class={[
        "w-full overflow-hidden rounded-lg",
        wrapper_height_class(@size),
        @class
      ]}
      {@rest}
    >
      <iframe
        src={build_widget_url(@theme, @type, @deezer_id, @color, @autoplay, @show_tracklist)}
        width="100%"
        height="100%"
        frameborder="0"
        allowtransparency="true"
        allow="encrypted-media; clipboard-write"
        loading="lazy"
        title={"Deezer #{@type} player"}
        class="block w-full h-full border-0 rounded-lg"
      >
      </iframe>
    </div>
    """
  end

  # AIDEV-NOTE: builds the Deezer widget iframe src; color must be passed without '#'
  defp build_widget_url(theme, type, id, color, autoplay, show_tracklist) do
    params =
      URI.encode_query(%{
        "autoplay" => if(autoplay, do: "true", else: "false"),
        "playlist" => if(show_tracklist, do: "true", else: "false"),
        "color" => color
      })

    "#{@deezer_widget_base}/#{theme}/#{type}/#{id}?#{params}"
  end

  defp wrapper_height_class("sm"), do: "h-24"
  defp wrapper_height_class("md"), do: "h-72"
  defp wrapper_height_class("lg"), do: "h-[450px]"
  defp wrapper_height_class("full"), do: "h-screen"
end
