defmodule Storybook.Components.Track do
  @moduledoc false

  use PhoenixStorybook.Story, :component

  alias PremiereEcoute.Discography.Album.Track

  def function, do: &PremiereEcouteWeb.Components.AlbumTrackDisplay.track_display/1
  def render_source, do: :function

  def variations do
    [
      %Variation{
        id: :basic,
        attributes: %{
          track: %Track{
            name: "Get Lucky",
            track_number: 8,
            duration_ms: 369_000
          },
          size: "md"
        }
      }
    ]
  end
end
