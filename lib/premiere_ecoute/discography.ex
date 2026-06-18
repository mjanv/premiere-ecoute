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

  use PremiereEcouteCore.Context

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Discography.Links
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Services.SyncPlaylistDiscography
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Discography.Workers.EnrichArtistWorker
  alias PremiereEcoute.Discography.Workers.EnrichDiscographyWorker

  # Album
  defdelegate create_album(album), to: Album, as: :create
  defdelegate get_album(id), to: Album, as: :get
  defdelegate get_album_by_slug(id), to: Album, as: :get_album_by_slug
  defdelegate list_albums(), to: Album, as: :all
  defdelegate last_albums(n \\ 5), to: Album, as: :last
  defdelegate list_albums_for_artist(artist_id), to: Album, as: :list_for_artist

  # Artist
  defdelegate get_artist_by_slug(slug), to: Artist, as: :get_by_slug
  defdelegate list_artists(), to: Artist, as: :all
  defdelegate last_artists(n \\ 5), to: Artist, as: :last

  # Single
  defdelegate get_single(id), to: Single, as: :get
  defdelegate get_single_by_slug(slug), to: Single, as: :get_by_slug
  defdelegate list_singles(), to: Single, as: :all
  defdelegate last_singles(n \\ 5), to: Single, as: :last
  defdelegate list_singles_for_artist(artist_id), to: Single, as: :list_for_artist

  # Playlist
  defdelegate create_playlist(playlist), to: Playlist, as: :create

  # Links
  defdelegate title(entity), to: Links
  defdelegate url(entity, provider), to: Links

  # Enrichment
  @spec enrich_artist(integer() | String.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enrich_artist(id), do: EnrichArtistWorker.now(%{"id" => id})

  @spec enrich_discography(integer() | String.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enrich_discography(id), do: EnrichDiscographyWorker.now(%{"id" => id})

  @spec sync_playlist(LibraryPlaylist.t()) ::
          {:ok, :unchanged} | {:ok, SyncPlaylistDiscography.result()} | {:error, term()}
  defdelegate sync_playlist(library_playlist), to: SyncPlaylistDiscography, as: :sync
end
