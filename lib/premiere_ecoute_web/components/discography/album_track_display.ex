defmodule PremiereEcouteWeb.Components.AlbumTrackDisplay do
  @moduledoc """
  Album, Track, and Playlist Display Components

  Provides consistent components for displaying album, track, and playlist information with cover images, 
  names, artists, and optional metadata across the application.

  ## Usage

      <.album_display album={@album} size="md" />
      <.track_display track={@track} show_duration={true} />
      <.playlist_display playlist={@playlist} size="md" show_metadata={true} />
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
    * `show_duration` - Whether to show track duration (default: true)
    * `size` - Size variant: "sm", "md" (default: "md")  
    * `clickable` - Whether the track should be clickable (default: false)
    * `class` - Additional CSS classes
    
  ## Examples

    <.track_display track={@track} size="sm" />
  """
  attr :track, :map, required: true
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
      <%= if @track.track_number do %>
        <span class={["text-gray-300 w-6 text-right mr-3", track_number_size_classes(@size)]}>
          {@track.track_number}
        </span>
      <% end %>

      <div class="flex-1 min-w-0">
        <h5 class={["font-medium text-white truncate", track_title_size_classes(@size)]}>
          {@track.name}
        </h5>
      </div>

      <%= if @show_duration && @track.duration_ms do %>
        <span class={["text-gray-300", track_duration_size_classes(@size)]}>
          {PremiereEcouteCore.Duration.timer(@track.duration_ms)}
        </span>
      <% end %>
    </div>
    """
  end

  # AIDEV-NOTE: Playlist display component with cover, name, creator, and metadata
  @doc """
  Renders a playlist display with cover image, name, creator, and optional metadata.

  ## Attributes

    * `playlist` - Playlist data structure with name, creator/owner, and optional cover_url
    * `size` - Size variant: "sm", "md", "lg", "xl" (default: "md")
    * `orientation` - Layout orientation: "horizontal", "vertical" (default: "horizontal")
    * `show_metadata` - Whether to show additional metadata like track count, duration (default: false)
    * `show_provider` - Whether to show provider badge (default: false)
    * `clickable` - Whether the playlist should be clickable (default: false)
    * `class` - Additional CSS classes
    
  ## Examples

      <.playlist_display playlist={%{title: "Playlist Name", owner_name: "Creator", cover_url: "..."}} />
      <.playlist_display playlist={@playlist} size="lg" orientation="vertical" />
      <.playlist_display playlist={@playlist} show_metadata={true} show_provider={true} />
  """
  attr :playlist, :map, required: true
  attr :size, :string, default: "md", values: ~w(sm md lg xl)
  attr :orientation, :string, default: "horizontal", values: ~w(horizontal vertical)
  attr :show_metadata, :boolean, default: false
  attr :show_provider, :boolean, default: false
  attr :clickable, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  def playlist_display(assigns) do
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
      <!-- Playlist cover -->
      <div class={["flex-shrink-0 relative", cover_size_classes(@size)]}>
        <%= if @playlist.cover_url do %>
          <img
            src={@playlist.cover_url}
            alt={@playlist.title || @playlist.name || "Playlist"}
            class={["object-cover rounded", cover_size_classes(@size)]}
            loading="lazy"
          />
        <% else %>
          <div class={[
            "bg-gradient-secondary-diagonal rounded flex items-center justify-center",
            cover_size_classes(@size)
          ]}>
            <svg class={["text-white/60", icon_size_classes(@size)]} fill="currentColor" viewBox="0 0 20 20">
              <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              <path d="M3 7v10a2 2 0 002 2h10a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2 2z" />
              <path d="M13 5h2a2 2 0 012 2v2h-2V7h-2V5zM5 5v2H3V5a2 2 0 012-2h2v2H5z" />
            </svg>
          </div>
        <% end %>
        
    <!-- Provider badge -->
        <%= if @show_provider && Map.get(@playlist, :provider) do %>
          <div class="absolute -top-1 -right-1">
            <div class={[
              "rounded-full flex items-center justify-center",
              provider_badge_size(@size),
              provider_badge_color(@playlist.provider)
            ]}>
              <svg class={["text-white", provider_icon_size(@size)]} fill="currentColor" viewBox="0 0 24 24">
                <%= if @playlist.provider == :spotify do %>
                  <path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.42 1.56-.299.421-1.02.599-1.559.3z" />
                <% else %>
                  <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z" />
                <% end %>
              </svg>
            </div>
          </div>
        <% end %>
      </div>
      
    <!-- Playlist details -->
      <div class={[
        content_spacing_classes(@orientation),
        if(@orientation == "vertical", do: "text-center", else: "flex-1 min-w-0")
      ]}>
        <h4 class={["font-semibold text-white truncate", title_size_classes(@size)]}>
          {@playlist.title || @playlist.name || "Untitled Playlist"}
        </h4>
        <p class={["text-gray-400 truncate", subtitle_size_classes(@size)]}>
          by {@playlist.owner_name || @playlist.creator || @playlist.owner || "Unknown Creator"}
        </p>

        <%= if @show_metadata do %>
          <div class={["flex items-center text-gray-500 mt-1", metadata_layout_classes(@orientation), metadata_size_classes(@size)]}>
            <%= if @playlist.total_tracks || Map.get(@playlist, :track_count) do %>
              <span class="flex items-center">
                <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"
                  />
                </svg>
                {@playlist.total_tracks || Map.get(@playlist, :track_count)} tracks
              </span>
            <% end %>

            <%= if (@playlist.total_duration_ms || Map.get(@playlist, :duration_ms)) && (@playlist.total_tracks || Map.get(@playlist, :track_count)) do %>
              <span class="mx-1">•</span>
            <% end %>

            <%= if @playlist.total_duration_ms || Map.get(@playlist, :duration_ms) do %>
              <span class="flex items-center">
                <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                {PremiereEcouteCore.Duration.timer(@playlist.total_duration_ms || Map.get(@playlist, :duration_ms))}
              </span>
            <% end %>

            <%= if (@playlist.visibility || Map.get(@playlist, :is_public)) && ((@playlist.total_duration_ms || Map.get(@playlist, :duration_ms)) || (@playlist.total_tracks || Map.get(@playlist, :track_count))) do %>
              <span class="mx-1">•</span>
            <% end %>

            <%= if @playlist.visibility == "public" || Map.get(@playlist, :is_public) do %>
              <span class="flex items-center text-green-400">
                <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                Public
              </span>
            <% else %>
              <%= if @playlist.visibility == "private" || Map.get(@playlist, :is_public) == false do %>
                <span class="flex items-center text-orange-400">
                  <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                    />
                  </svg>
                  Private
                </span>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>
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

  defp track_duration_size_classes("sm"), do: "text-xs"
  defp track_duration_size_classes("md"), do: "text-sm"

  # Playlist-specific helper functions
  defp provider_badge_size("sm"), do: "w-4 h-4"
  defp provider_badge_size("md"), do: "w-5 h-5"
  defp provider_badge_size("lg"), do: "w-6 h-6"
  defp provider_badge_size("xl"), do: "w-7 h-7"

  defp provider_icon_size("sm"), do: "w-2 h-2"
  defp provider_icon_size("md"), do: "w-3 h-3"
  defp provider_icon_size("lg"), do: "w-4 h-4"
  defp provider_icon_size("xl"), do: "w-5 h-5"

  defp provider_badge_color(:spotify), do: "bg-green-600 border border-green-500/50"
  defp provider_badge_color(:deezer), do: "bg-orange-600 border border-orange-500/50"
  defp provider_badge_color(:apple_music), do: "bg-red-600 border border-red-500/50"
  defp provider_badge_color(_), do: "bg-gray-600 border border-gray-500/50"
end
