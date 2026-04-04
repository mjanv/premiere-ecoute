defmodule PremiereEcoute.Discography.Services.EnrichDiscography do
  @moduledoc """
  Enriches the discography of an artist by fetching all their albums from Spotify
  and persisting any that are not already in the database.

  Requires the artist to have a Spotify provider ID. Albums are fetched in parallel,
  then each is created if not already present.
  """

  require Logger

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Discography.Supervisor

  @doc """
  Fetches all Spotify albums for the given artist and creates any missing ones.
  """
  @spec create_discography(Artist.t()) :: {:ok, [Album.t()]} | {:error, term()}
  def create_discography(%Artist{provider_ids: %{spotify: spotify_id}}) do
    with {:ok, albums} <- Apis.spotify().get_artist_albums(spotify_id) do
      albums
      |> Supervisor.async(fn %{provider_ids: %{spotify: id}} -> create_album(id, :spotify) end)
      |> Stream.filter(&match?({:ok, _}, &1))
      |> Enum.reduce({:ok, []}, fn {:ok, album}, {:ok, albums} -> {:ok, albums ++ [album]} end)
    end
  end

  def create_discography(%Artist{}) do
    {:error, :no_spotify_id}
  end

  @spec create_album(String.t(), atom()) :: {:ok, Album.t()} | {:error, term()}
  def create_album(album_id, provider \\ :spotify) do
    with {:ok, %Album{} = album} <- Apis.provider(provider).get_album(album_id),
         {:ok, %Album{} = album} <- Album.create_if_not_exists(album) do
      Logger.info("Album created")
      {:ok, album}
    end
  end

  @spec create_single(String.t(), atom()) :: {:ok, Single.t()} | {:error, term()}
  def create_single(single_id, provider \\ :spotify) do
    with {:ok, %Single{} = single} <- Apis.provider(provider).get_single(single_id),
         {:ok, %Single{} = single} <- Single.create_if_not_exists(single) do
      Logger.info("Single created")
      {:ok, single}
    end
  end
end
