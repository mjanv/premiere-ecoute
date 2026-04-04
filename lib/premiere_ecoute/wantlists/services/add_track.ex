defmodule PremiereEcoute.Wantlists.Services.AddTrack do
  @moduledoc """
  Adds a radio track to a user's wantlist by Spotify track ID.

  Looks up the track in the local discography first. If not found, fetches it
  from Spotify and creates the appropriate record — a Single for standalone
  singles, or an Album for album tracks — then adds it to the wantlist.
  """

  import Ecto.Query

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Services.EnrichDiscography
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Wantlists.WantlistItem

  @spec add_radio_track(integer(), String.t()) :: {:ok, WantlistItem.t()} | {:error, term()}
  def add_radio_track(user_id, spotify_id) do
    case find_existing(spotify_id) do
      {:single, single} -> WantlistItem.add(user_id, :track, single.id)
      {:album, album} -> WantlistItem.add(user_id, :album, album.id)
      :not_found -> fetch_create_and_add(user_id, spotify_id)
    end
  end

  defp find_existing(spotify_id) do
    single =
      Single
      |> where([s], fragment("?->>'spotify' = ?", s.provider_ids, ^spotify_id))
      |> Repo.one()

    album =
      if is_nil(single) do
        Album
        |> join(:inner, [a], t in assoc(a, :tracks))
        |> where([_a, t], fragment("?->>'spotify' = ?", t.provider_ids, ^spotify_id))
        |> Repo.one()
      end

    case {single, album} do
      {%Single{} = s, _} -> {:single, s}
      {nil, %Album{} = a} -> {:album, a}
      {nil, nil} -> :not_found
    end
  end

  defp fetch_create_and_add(user_id, spotify_id) do
    case Apis.spotify().get_single(spotify_id) do
      {:ok, single} ->
        with {:ok, single} <- Single.create_if_not_exists(single) do
          WantlistItem.add(user_id, :track, single.id)
        end

      {:error, :no_track_found} ->
        with {:ok, track} <- Apis.spotify().get_track(spotify_id),
             album_spotify_id <- Map.get(track, :album_spotify_id),
             {:ok, album} <- EnrichDiscography.create_album(album_spotify_id) do
          WantlistItem.add(user_id, :album, album.id)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
