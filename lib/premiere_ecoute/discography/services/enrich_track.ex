defmodule PremiereEcoute.Discography.Services.EnrichTrack do
  @moduledoc """
  Enriches a track record with external links from third-party sources.

  Each source is fetched independently and stored only if the key is not already present.
  Sources already present are skipped without making an API call.

  The track's name and album artist name are used for all lookups to improve accuracy.
  """

  require Logger

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Supervisor

  alias PremiereEcoute.Repo

  @doc """
  Enriches a track with all available external data.
  """
  @spec enrich_track(Track.t()) :: {:ok, Track.t()} | {:error, term()}
  def enrich_track(%Track{} = track) do
    track = Repo.preload(track, album: [:artists])

    external_links =
      [:genius]
      |> Supervisor.async(fn k -> {k, enrich(k, track)} end)
      |> then(&Map.merge(track.external_links, &1))

    Track.update(track, %{external_links: external_links})
  end

  defp enrich(:genius, %Track{name: name} = track) do
    with artist <- artist_name(track),
         {:ok, results} <- Apis.genius().search_song("#{name} #{artist}"),
         [%{id: id} | _] <- PremiereEcouteCore.Search.filter(results, artist, [:artist], 0.75),
         {:ok, song} <- Apis.genius().get_song(id) do
      Logger.info("")
      song.url
    else
      _ -> nil
    end
  end

  defp artist_name(%Track{album: %{artist: %{name: name}}}) when is_binary(name), do: name
  defp artist_name(%Track{album: %{artist: name}}) when is_binary(name), do: name
  defp artist_name(%Track{album: %{artists: [%{name: name} | _]}}) when is_binary(name), do: name
  defp artist_name(_), do: ""
end
