# AIDEV-NOTE: Storybook story for track display component

defmodule Storybook.CoreComponents.TrackDisplay do
  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.AlbumTrackDisplay.track_display/1
  def imports, do: [{PremiereEcouteWeb.Components.AlbumTrackDisplay, [track_display: 1]}]

  def template do
    """
    <.psb-variation/>
    """
  end

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default track display with name and duration",
        attributes: %{
          track: %{
            name: "Bohemian Rhapsody",
            duration_ms: 354000
          }
        }
      },
      %Variation{
        id: :with_track_number,
        description: "Track display with track number",
        attributes: %{
          track: %{
            name: "Come As You Are",
            duration_ms: 219000
          },
          track_number: 1
        }
      },
      %Variation{
        id: :no_duration,
        description: "Track display without duration",
        attributes: %{
          track: %{
            name: "Smells Like Teen Spirit"
          },
          show_duration: false
        }
      },
      %Variation{
        id: :with_featured_artist,
        description: "Track with featured artist different from album artist",
        attributes: %{
          track: %{
            name: "Old Town Road (Remix)",
            artist: "Lil Nas X feat. Billy Ray Cyrus",
            album_artist: "Lil Nas X",
            duration_ms: 157000
          },
          track_number: 1
        }
      },
      %Variation{
        id: :sizes,
        description: "Different size variants",
        template: """
        <div class="space-y-4">
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">Small</h3>
            <.track_display 
              track={%{name: "Imagine", duration_ms: 183000}} 
              track_number={1}
              size="sm" 
            />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">Medium (default)</h3>
            <.track_display 
              track={%{name: "Imagine", duration_ms: 183000}} 
              track_number={1}
              size="md" 
            />
          </div>
        </div>
        """
      },
      %Variation{
        id: :tracklist,
        description: "Multiple tracks in a tracklist",
        template: """
        <div class="bg-gray-800 rounded-lg p-4 space-y-1">
          <.track_display 
            track={%{name: "Money", duration_ms: 382000}} 
            track_number={1}
            clickable={true}
          />
          <.track_display 
            track={%{name: "Us and Them", duration_ms: 469000}} 
            track_number={2}
            clickable={true}
          />
          <.track_display 
            track={%{name: "Any Colour You Like", duration_ms: 205000}} 
            track_number={3}
            clickable={true}
          />
          <.track_display 
            track={%{name: "Brain Damage", duration_ms: 228000}} 
            track_number={4}
            clickable={true}
          />
          <.track_display 
            track={%{name: "Eclipse", duration_ms: 123000}} 
            track_number={5}
            clickable={true}
          />
        </div>
        """
      }
    ]
  end
end