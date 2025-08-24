defmodule Storybook.Components.Discography.Playlist do
  @moduledoc """
  Storybook stories for playlist display components
  """

  use PhoenixStorybook.Story, :component

  alias PremiereEcoute.Discography.Playlist

  def function, do: &PremiereEcouteWeb.CoreComponents.playlist_display/1

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{
          playlist: %Playlist{
            title: "Indie Rock Favorites",
            owner_name: "MusicLover123",
            cover_url: "https://i.scdn.co/image/ab67616d00001e02ff9ca10b55ce82ae553c8228",
            provider: :spotify,
            playlist_id: "12345",
            public: true
          }
        }
      },
      %Variation{
        id: :with_description,
        attributes: %{
          playlist: %Playlist{
            title: "Road Trip Essentials",
            owner_name: "DJ Highway",
            description: "Perfect songs for long drives and adventures",
            cover_url: "https://i.scdn.co/image/ab67616d00001e02ff9ca10b55ce82ae553c8228",
            provider: :spotify,
            playlist_id: "67890",
            public: true
          }
        }
      },
      %Variation{
        id: :deezer_playlist,
        attributes: %{
          playlist: %Playlist{
            title: "Electronic Vibes",
            owner_name: "BeatMaster",
            description: "The best electronic tracks",
            cover_url: "https://i.scdn.co/image/ab67616d00001e02ff9ca10b55ce82ae553c8228",
            provider: :deezer,
            playlist_id: "abc123",
            public: false
          }
        }
      },
      %Variation{
        id: :no_cover,
        attributes: %{
          playlist: %Playlist{
            title: "My Awesome Playlist",
            owner_name: "Anonymous User",
            provider: :spotify,
            playlist_id: "no-cover",
            public: true
          }
        }
      },
      %Variation{
        id: :private_playlist,
        attributes: %{
          playlist: %Playlist{
            title: "My Personal Mix",
            owner_name: "PrivateUser",
            cover_url: "https://i.scdn.co/image/ab67616d00001e02ff9ca10b55ce82ae553c8228",
            provider: :spotify,
            playlist_id: "private-123",
            public: false
          }
        }
      },
      %Variation{
        id: :with_long_description,
        attributes: %{
          playlist: %Playlist{
            title: "Ultimate Chill Vibes Collection for Long Study Sessions and Relaxation",
            owner_name: "VeryLongUsernameForTesting",
            description:
              "This is a very long description that should demonstrate how the component handles extensive text content and potentially truncates or wraps appropriately within the design constraints of the interface.",
            cover_url: "https://i.scdn.co/image/ab67616d00001e02ff9ca10b55ce82ae553c8228",
            provider: :deezer,
            playlist_id: "long-text",
            public: true
          }
        }
      }
    ]
  end
end
