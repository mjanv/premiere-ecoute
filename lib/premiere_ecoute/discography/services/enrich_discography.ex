defmodule PremiereEcoute.Discography.Services.EnrichDiscography do
  @moduledoc """
  Enriches the discography of an artist by fetching all their albums from Spotify
  and persisting any that are not already in the database.

  Requires the artist to have a Spotify provider ID. Albums are fetched in parallel,
  then each is created if not already present.
  """

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist

  @doc """
  Fetches all Spotify albums for the given artist and creates any missing ones.

  Returns `{:ok, [Album.t()]}` with the list of persisted albums, or
  `{:error, :no_spotify_id}` if the artist has no Spotify provider ID.
  """
  @spec enrich_discography(Artist.t()) :: {:ok, [Album.t()]} | {:error, term()}
  def enrich_discography(%Artist{provider_ids: %{spotify: spotify_id}} = _artist)
      when is_binary(spotify_id) do
    with {:ok, albums} <- SpotifyApi.get_artist_albums(spotify_id) do
      albums =
        PremiereEcoute.Discography.TaskSupervisor
        |> Task.Supervisor.async_stream(albums, fn %{provider_ids: %{spotify: id}} ->
          with {:ok, album} <- SpotifyApi.get_album(id) do
            Album.create_if_not_exists(album)
          end
        end)
        |> Enum.flat_map(fn
          {:ok, {:ok, album}} -> [album]
          _ -> []
        end)

      {:ok, albums}
    end
  end

  def enrich_discography(%Artist{}) do
    {:error, :no_spotify_id}
  end
end
