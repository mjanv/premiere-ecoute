defmodule Storybook.Components.DeezerWidget do
  @moduledoc """
  Storybook for the Deezer embed widget component.

  Showcases all supported resource types (album, playlist, track, artist),
  size presets, themes, and accent color customization.

  > Note: variations use real Deezer IDs for live preview. Replace them with
  > any valid Deezer resource ID when testing locally.
  """

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.DeezerWidget.deezer_widget/1
  def render_source, do: :function

  def variations do
    [
      # -----------------------------------------------------------------------
      # Resource types
      # -----------------------------------------------------------------------
      %VariationGroup{
        id: :types,
        description: "Supported Deezer resource types",
        variations: [
          %Variation{
            id: :album,
            description: "Album widget",
            attributes: %{
              type: "album",
              deezer_id: "302127",
              size: "md"
            }
          },
          %Variation{
            id: :playlist,
            description: "Playlist widget",
            attributes: %{
              type: "playlist",
              deezer_id: "908622995",
              size: "md"
            }
          },
          %Variation{
            id: :track,
            description: "Single track widget (minimal bar)",
            attributes: %{
              type: "track",
              deezer_id: "3135556",
              size: "sm"
            }
          },
          %Variation{
            id: :artist,
            description: "Artist widget",
            attributes: %{
              type: "artist",
              deezer_id: "27",
              size: "md"
            }
          }
        ]
      },

      # -----------------------------------------------------------------------
      # Size presets
      # -----------------------------------------------------------------------
      %VariationGroup{
        id: :sizes,
        description: "Size presets — width always fills the parent container",
        variations: [
          %Variation{
            id: :small,
            description: "sm — compact player bar (92px height)",
            attributes: %{
              type: "track",
              deezer_id: "3135556",
              size: "sm"
            }
          },
          %Variation{
            id: :medium,
            description: "md — standard embed (288px height)",
            attributes: %{
              type: "album",
              deezer_id: "302127",
              size: "md"
            }
          },
          %Variation{
            id: :large,
            description: "lg — taller embed with more tracks visible (450px height)",
            attributes: %{
              type: "album",
              deezer_id: "302127",
              size: "lg"
            }
          }
        ]
      },

      # -----------------------------------------------------------------------
      # Themes
      # -----------------------------------------------------------------------
      %VariationGroup{
        id: :themes,
        description: "Color themes",
        variations: [
          %Variation{
            id: :dark,
            description: "Dark theme (default)",
            attributes: %{
              type: "album",
              deezer_id: "302127",
              size: "md",
              theme: "dark"
            }
          },
          %Variation{
            id: :light,
            description: "Light theme",
            attributes: %{
              type: "album",
              deezer_id: "302127",
              size: "md",
              theme: "light"
            }
          },
          %Variation{
            id: :auto,
            description: "Auto theme — follows system preference",
            attributes: %{
              type: "album",
              deezer_id: "302127",
              size: "md",
              theme: "auto"
            }
          }
        ]
      },

      # -----------------------------------------------------------------------
      # Accent colors
      # -----------------------------------------------------------------------
      %VariationGroup{
        id: :colors,
        description: "Custom accent colors (hex without '#')",
        variations: [
          %Variation{
            id: :orange,
            description: "Default Deezer orange — EF6C00",
            attributes: %{
              type: "album",
              deezer_id: "302127",
              size: "md",
              color: "EF6C00"
            }
          },
          %Variation{
            id: :purple,
            description: "Purple accent — 7C3AED",
            attributes: %{
              type: "album",
              deezer_id: "302127",
              size: "md",
              color: "7C3AED"
            }
          },
          %Variation{
            id: :green,
            description: "Green accent — 16A34A",
            attributes: %{
              type: "album",
              deezer_id: "302127",
              size: "md",
              color: "16A34A"
            }
          }
        ]
      },

      # -----------------------------------------------------------------------
      # Options
      # -----------------------------------------------------------------------
      %VariationGroup{
        id: :options,
        description: "Tracklist and autoplay options",
        variations: [
          %Variation{
            id: :no_tracklist,
            description: "Tracklist hidden",
            attributes: %{
              type: "album",
              deezer_id: "302127",
              size: "md",
              show_tracklist: false
            }
          },
          %Variation{
            id: :with_tracklist,
            description: "Tracklist visible (default)",
            attributes: %{
              type: "album",
              deezer_id: "302127",
              size: "md",
              show_tracklist: true
            }
          }
        ]
      }
    ]
  end
end
