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
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Single

  # Album
  defdelegate create_album(album), to: Album, as: :create
  defdelegate get_album(id), to: Album, as: :get
  defdelegate get_album_by_slug(id), to: Album, as: :get_album_by_slug
  defdelegate list_albums(), to: Album, as: :all

  # Artist
  defdelegate get_artist_by_slug(slug), to: Artist, as: :get_by_slug
  defdelegate list_artists(), to: Artist, as: :all

  # Single
  defdelegate get_single(id), to: Single, as: :get
  defdelegate get_single_by_slug(slug), to: Single, as: :get_by_slug
  defdelegate list_singles(), to: Single, as: :all

  # Playlist
  defdelegate create_playlist(playlist), to: Playlist, as: :create

  @spec title(any()) :: String.t() | nil
  def title(%{title: title}), do: title
  def title(%{name: name}), do: name
  def title(_), do: nil

  @spec url(any()) :: String.t() | nil
  def url(%Album{provider: :spotify, album_id: id}), do: "https://open.spotify.com/album/#{id}"

  def url(%Album.Track{provider: :spotify, track_id: id}), do: "https://open.spotify.com/track/#{id}"
  def url(%Album.Track{provider: :deezer, track_id: id}), do: "https://www.deezer.com/track/#{id}"

  def url(%Single{provider: :spotify, track_id: id}), do: "https://open.spotify.com/track/#{id}"

  def url(%Playlist{provider: :spotify, playlist_id: id}), do: "https://open.spotify.com/playlist/#{id}"
  def url(%Playlist{provider: :deezer, playlist_id: id}), do: "https://www.deezer.com/playlist/#{id}"

  def url(_), do: nil
end
