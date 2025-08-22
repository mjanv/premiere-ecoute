defmodule PremiereEcouteWeb.Components.AlbumTrackDisplay do
  @moduledoc """
  Album and Track Display Components

  Provides consistent components for displaying album information with cover images, 
  names, artists, and optional metadata across the application.

  ## Usage

      <.album_display album={@album} size="md" />
      <.track_display track={@track} show_duration={true} />
      
  ## Design System Notes

  - Uses consistent sizing variants for different contexts
  - Graceful fallback for missing cover images with gradient placeholders
  - Follows the design system color variables for consistent theming
  - Supports different layout orientations for various use cases
  """

  use Phoenix.Component

  # AIDEV-NOTE: Album display component with consistent cover image and metadata layout
  @doc """
  Renders an album display with cover image, name, and artist.

  ## Attributes

    * `album` - Album data structure with name, artist, and optional cover_url
    * `size` - Size variant: "sm", "md", "lg", "xl" (default: "md")
    * `orientation` - Layout orientation: "horizontal", "vertical" (default: "horizontal")
    * `show_metadata` - Whether to show additional metadata like track count, year (default: false)
    * `clickable` - Whether the album display should be clickable (default: false)
    * `class` - Additional CSS classes
    
  ## Examples

      <.album_display album={%{name: "Album Name", artist: "Artist", cover_url: "..."}} />
      <.album_display album={@album} size="lg" orientation="vertical" />
      <.album_display album={@album} show_metadata={true} clickable={true} />
  """
  attr :album, :map, required: true
  attr :size, :string, default: "md", values: ~w(sm md lg xl)
  attr :orientation, :string, default: "horizontal", values: ~w(horizontal vertical)
  attr :show_metadata, :boolean, default: false
  attr :clickable, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  def album_display(assigns) do
    ~H"""
    <div
      class={[
        "flex",
        orientation_classes(@orientation),
        if(@clickable, do: "cursor-pointer hover:opacity-80 transition-opacity"),
        @class
      ]}
      {@rest}
    >
      <!-- Album cover -->
      <div class={["flex-shrink-0", cover_size_classes(@size)]}>
        <%= if @album.cover_url do %>
          <img src={@album.cover_url} alt={@album.name} class={["object-cover rounded", cover_size_classes(@size)]} loading="lazy" />
        <% else %>
          <div class={[
            "bg-gradient-primary-diagonal rounded flex items-center justify-center",
            cover_size_classes(@size)
          ]}>
            <svg class={["text-white/60", icon_size_classes(@size)]} fill="currentColor" viewBox="0 0 20 20">
              <path d="M18 3a1 1 0 00-1.196-.98L3 6.687a1 1 0 000 1.838l4.49 1.497L9.5 14.75a1 1 0 001.838 0L15.014 10H18a1 1 0 001-1V4a1 1 0 00-1-1z" />
            </svg>
          </div>
        <% end %>
      </div>
      
    <!-- Album details -->
      <div class={[
        content_spacing_classes(@orientation),
        if(@orientation == "vertical", do: "text-center", else: "flex-1 min-w-0")
      ]}>
        <h4 class={["font-semibold text-white truncate", title_size_classes(@size)]}>
          {@album.name}
        </h4>
        <p class={["text-gray-400 truncate", subtitle_size_classes(@size)]}>
          {@album.artist || Map.get(@album, :artist_name) || "Unknown Artist"}
        </p>

        <%= if @show_metadata do %>
          <div class={["flex items-center text-gray-500 mt-1", metadata_layout_classes(@orientation), metadata_size_classes(@size)]}>
            <%= if @album.total_tracks do %>
              <span class="flex items-center">
                <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"
                  />
                </svg>
                {@album.total_tracks} tracks
              </span>
            <% end %>

            <%= if @album.release_date && @album.total_tracks do %>
              <span class="mx-1">•</span>
            <% end %>

            <%= if @album.release_date do %>
              <span>{@album.release_date.year || Map.get(@album, :release_year)}</span>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # AIDEV-NOTE: Track display component for individual tracks with optional duration and controls
  @doc """
  Renders a track display with name, optional duration, and track number.

  ## Attributes

    * `track` - Track data structure with name and optional duration_ms
    * `track_number` - Optional track number to display
    * `show_duration` - Whether to show track duration (default: true)
    * `size` - Size variant: "sm", "md" (default: "md")  
    * `clickable` - Whether the track should be clickable (default: false)
    * `class` - Additional CSS classes
    
  ## Examples

      <.track_display track={%{name: "Track Name", duration_ms: 180000}} />
      <.track_display track={@track} track_number={1} size="sm" />
  """
  attr :track, :map, required: true
  attr :track_number, :integer, default: nil
  attr :show_duration, :boolean, default: true
  attr :size, :string, default: "md", values: ~w(sm md)
  attr :clickable, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  def track_display(assigns) do
    ~H"""
    <div
      class={[
        "flex items-center",
        if(@clickable, do: "cursor-pointer hover:bg-white/5 transition-colors rounded-lg p-2 -m-2"),
        @class
      ]}
      {@rest}
    >
      <%= if @track_number do %>
        <span class={["text-gray-300 w-6 text-right mr-3", track_number_size_classes(@size)]}>
          {@track_number}
        </span>
      <% end %>

      <div class="flex-1 min-w-0">
        <h5 class={["font-medium text-white truncate", track_title_size_classes(@size)]}>
          {@track.name}
        </h5>
        <%= if @track.artist && @track.artist != Map.get(@track, :album_artist) do %>
          <p class={["text-gray-400 truncate", track_artist_size_classes(@size)]}>
            {@track.artist}
          </p>
        <% end %>
      </div>

      <%= if @show_duration && @track.duration_ms do %>
        <span class={["text-gray-300", track_duration_size_classes(@size)]}>
          {PremiereEcouteCore.Duration.timer(@track.duration_ms)}
        </span>
      <% end %>
    </div>
    """
  end

  # AIDEV-NOTE: Utility functions for consistent sizing and styling

  # Cover image size classes
  defp cover_size_classes("sm"), do: "w-8 h-8"
  defp cover_size_classes("md"), do: "w-12 h-12"
  defp cover_size_classes("lg"), do: "w-16 h-16"
  defp cover_size_classes("xl"), do: "w-24 h-24"

  # Icon size classes for placeholder covers
  defp icon_size_classes("sm"), do: "w-4 h-4"
  defp icon_size_classes("md"), do: "w-6 h-6"
  defp icon_size_classes("lg"), do: "w-8 h-8"
  defp icon_size_classes("xl"), do: "w-12 h-12"

  # Content spacing based on orientation
  defp content_spacing_classes("horizontal"), do: "ml-3"
  defp content_spacing_classes("vertical"), do: "mt-2"

  # Layout orientation classes
  defp orientation_classes("horizontal"), do: "items-center space-x-0"
  defp orientation_classes("vertical"), do: "flex-col items-center space-y-0"

  # Title size classes
  defp title_size_classes("sm"), do: "text-sm"
  defp title_size_classes("md"), do: "text-base"
  defp title_size_classes("lg"), do: "text-lg"
  defp title_size_classes("xl"), do: "text-xl"

  # Subtitle size classes
  defp subtitle_size_classes("sm"), do: "text-xs"
  defp subtitle_size_classes("md"), do: "text-sm"
  defp subtitle_size_classes("lg"), do: "text-base"
  defp subtitle_size_classes("xl"), do: "text-lg"

  # Metadata layout classes
  defp metadata_layout_classes("horizontal"), do: "space-x-2"
  defp metadata_layout_classes("vertical"), do: "justify-center space-x-2"

  # Metadata size classes
  defp metadata_size_classes("sm"), do: "text-xs"
  defp metadata_size_classes("md"), do: "text-xs"
  defp metadata_size_classes("lg"), do: "text-sm"
  defp metadata_size_classes("xl"), do: "text-sm"

  # Track-specific size classes
  defp track_number_size_classes("sm"), do: "text-xs"
  defp track_number_size_classes("md"), do: "text-sm"

  defp track_title_size_classes("sm"), do: "text-sm"
  defp track_title_size_classes("md"), do: "text-base"

  defp track_artist_size_classes("sm"), do: "text-xs"
  defp track_artist_size_classes("md"), do: "text-sm"

  defp track_duration_size_classes("sm"), do: "text-xs"
  defp track_duration_size_classes("md"), do: "text-sm"
end
