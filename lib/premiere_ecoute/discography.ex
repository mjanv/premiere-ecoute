defmodule PremiereEcoute.Discography do
  @moduledoc """
  Context module for managing music discography data.

  The Discography context handles the storage and retrieval of music catalog data
  including albums and tracks sourced from Spotify's API. This data forms the foundation
  for listening sessions where users can discover, rate, and discuss music.

  ## Core Entities

  - `Album` - Represents a music album with metadata and associated tracks
  - `Track` - Individual songs within an album with track-specific information
  """

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Playlist

  # Album
  defdelegate create_album(album), to: Album, as: :create
  defdelegate get_album(id), to: Album, as: :get

  # Playlist
  defdelegate create_playlist(playlist), to: Playlist, as: :create
end
