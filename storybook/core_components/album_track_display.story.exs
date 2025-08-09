# AIDEV-NOTE: Storybook story for AlbumTrackDisplay components showcasing medium priority refactoring

defmodule Storybook.CoreComponents.AlbumTrackDisplay do
  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.AlbumTrackDisplay.album_display/1
  def imports, do: [{PremiereEcouteWeb.Components.AlbumTrackDisplay, [album_display: 1, track_display: 1]}]

  def template do
    """
    <.psb-variation/>
    """
  end

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default album display with cover, name and artist",
        attributes: %{
          album: %{
            name: "The Dark Side of the Moon",
            artist: "Pink Floyd",
            cover_url: "https://i.scdn.co/image/ab67616d0000b2734bd33740f3b77e9a5e2e6daa"
          }
        }
      },
      %Variation{
        id: :no_cover,
        description: "Album display without cover image (shows fallback gradient)",
        attributes: %{
          album: %{
            name: "Unknown Album",
            artist: "Unknown Artist",
            cover_url: nil
          }
        }
      },
      %Variation{
        id: :with_metadata,
        description: "Album display with additional metadata",
        attributes: %{
          album: %{
            name: "Abbey Road",
            artist: "The Beatles",
            cover_url: "https://i.scdn.co/image/ab67616d0000b273dc30583ba717007b00cceb25",
            total_tracks: 17,
            release_date: %{year: 1969}
          },
          show_metadata: true
        }
      },
      %Variation{
        id: :sizes,
        description: "Different size variants",
        template: """
        <div class="space-y-6">
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">Small</h3>
            <.album_display 
              album={%{name: "Thriller", artist: "Michael Jackson", cover_url: "https://i.scdn.co/image/ab67616d0000b273de437d960dda1ac0a3586b8a"}} 
              size="sm" 
            />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">Medium (default)</h3>
            <.album_display 
              album={%{name: "Thriller", artist: "Michael Jackson", cover_url: "https://i.scdn.co/image/ab67616d0000b273de437d960dda1ac0a3586b8a"}} 
              size="md" 
            />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">Large</h3>
            <.album_display 
              album={%{name: "Thriller", artist: "Michael Jackson", cover_url: "https://i.scdn.co/image/ab67616d0000b273de437d960dda1ac0a3586b8a"}} 
              size="lg" 
            />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">Extra Large</h3>
            <.album_display 
              album={%{name: "Thriller", artist: "Michael Jackson", cover_url: "https://i.scdn.co/image/ab67616d0000b273de437d960dda1ac0a3586b8a"}} 
              size="xl" 
            />
          </div>
        </div>
        """
      },
      %Variation{
        id: :orientations,
        description: "Horizontal and vertical orientations",
        template: """
        <div class="space-y-8">
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">Horizontal (default)</h3>
            <.album_display 
              album={%{name: "Back in Black", artist: "AC/DC", cover_url: "https://i.scdn.co/image/ab67616d0000b273b5c60f85af34dbec8e3b7aee"}} 
              orientation="horizontal" 
              size="lg"
            />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">Vertical</h3>
            <.album_display 
              album={%{name: "Back in Black", artist: "AC/DC", cover_url: "https://i.scdn.co/image/ab67616d0000b273b5c60f85af34dbec8e3b7aee"}} 
              orientation="vertical" 
              size="lg"
            />
          </div>
        </div>
        """
      },
      %Variation{
        id: :clickable,
        description: "Clickable album display with hover effects",
        attributes: %{
          album: %{
            name: "Hotel California",
            artist: "Eagles",
            cover_url: "https://i.scdn.co/image/ab67616d0000b273ce4f1737bc8a646c8c4bd25a"
          },
          clickable: true
        }
      }
    ]
  end
end