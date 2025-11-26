defmodule Storybook.Components.Album do
  @moduledoc """
  Storybook for album display component.

  Displays variations of album display components showing album information including name, artist, and cover art.
  """

  use PhoenixStorybook.Story, :component

  alias PremiereEcoute.Discography.Album

  def function, do: &PremiereEcouteWeb.Components.AlbumTrackDisplay.album_display/1
  def render_source, do: :function

  def variations do
    [
      %Variation{
        id: :basic,
        attributes: %{
          album: %Album{
            name: "Random Access Memories",
            artist: "Daft Punk",
            cover_url: "https://i.scdn.co/image/ab67616d0000b273e319baafd16e84f0408af2a0"
          },
          size: "md"
        }
      }
    ]
  end
end
