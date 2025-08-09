defmodule PremiereEcouteWeb.Components.AlbumDisplay do
  @moduledoc """
  Album and track display components for consistent media information presentation.
  """
  use Phoenix.Component

  alias PremiereEcouteWeb.CoreComponents

  @doc """
  Renders an album or track display with cover image and information.

  ## Examples

      <.album_display
        cover_url={@album.cover_url}
        title={@album.name}
        subtitle={@album.artist}
      />

      <.album_display
        cover_url={@track.album.cover_url}
        title={@track.name}
        subtitle={@track.artist}
        size="sm"
        show_placeholder_icon={true}
      />
  """
  attr :cover_url, :string, default: nil, doc: "URL for the album/track cover image"
  attr :title, :string, required: true, doc: "Main title (album name or track name)"
  attr :subtitle, :string, default: nil, doc: "Subtitle (artist name or album name for tracks)"
  attr :size, :string, default: "md", values: ~w(xs sm md lg xl), doc: "Size variant"
  attr :show_placeholder_icon, :boolean, default: true, doc: "Show music icon when no cover_url"
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(phx-click phx-value-id href navigate patch)

  def album_display(assigns) do
    icon_classes =
      [
        "text-surface-muted",
        size_icon_classes(assigns.size)
      ]
      |> Enum.join(" ")

    assigns = assign(assigns, :icon_classes, icon_classes)

    ~H"""
    <div
      class={[
        "flex items-center",
        size_spacing_classes(@size),
        @class
      ]}
      {@rest}
    >
      <!-- Cover Image or Placeholder -->
      <div class={[
        "flex-shrink-0 rounded-lg overflow-hidden",
        size_image_classes(@size)
      ]}>
        <%= if @cover_url do %>
          <img src={@cover_url} alt={@title} class="w-full h-full object-cover" />
        <% else %>
          <div class={[
            "bg-surface-interactive flex items-center justify-center",
            size_image_classes(@size)
          ]}>
            <%= if @show_placeholder_icon do %>
              <CoreComponents.icon name="hero-musical-note" class={@icon_classes} />
            <% end %>
          </div>
        <% end %>
      </div>
      
    <!-- Text Information -->
      <div class="flex-1 min-w-0">
        <h4
          class={[
            "font-semibold text-surface-primary truncate",
            size_title_classes(@size)
          ]}
          title={@title}
        >
          {@title}
        </h4>
        <%= if @subtitle do %>
          <p
            class={[
              "text-surface-muted truncate mt-1",
              size_subtitle_classes(@size)
            ]}
            title={@subtitle}
          >
            {@subtitle}
          </p>
        <% end %>
      </div>
    </div>
    """
  end

  # AIDEV-NOTE: Size helper functions for responsive album display components
  defp size_spacing_classes(size) do
    case size do
      "xs" -> "space-x-2"
      "sm" -> "space-x-3"
      "md" -> "space-x-3"
      "lg" -> "space-x-4"
      "xl" -> "space-x-4"
    end
  end

  defp size_image_classes(size) do
    case size do
      "xs" -> "w-8 h-8"
      "sm" -> "w-12 h-12"
      "md" -> "w-16 h-16"
      "lg" -> "w-20 h-20"
      "xl" -> "w-24 h-24"
    end
  end

  defp size_icon_classes(size) do
    case size do
      "xs" -> "w-3 h-3"
      "sm" -> "w-4 h-4"
      "md" -> "w-6 h-6"
      "lg" -> "w-8 h-8"
      "xl" -> "w-10 h-10"
    end
  end

  defp size_title_classes(size) do
    case size do
      "xs" -> "text-xs"
      "sm" -> "text-sm"
      "md" -> "text-base"
      "lg" -> "text-lg"
      "xl" -> "text-xl"
    end
  end

  defp size_subtitle_classes(size) do
    case size do
      "xs" -> "text-xs"
      "sm" -> "text-xs"
      "md" -> "text-sm"
      "lg" -> "text-base"
      "xl" -> "text-lg"
    end
  end
end
