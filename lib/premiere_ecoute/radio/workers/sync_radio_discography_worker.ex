defmodule PremiereEcoute.Radio.Workers.SyncRadioDiscographyWorker do
  @moduledoc """
  Oban cron worker that feeds the discography from yesterday's radio tracks.

  For each unique Spotify track ID played yesterday across all streamers:
  1. Skip if the track is already in album_tracks (album and artist already known)
  2. Call get_track to resolve the Spotify artist ID (singles return nil and are skipped)
  3. Deduplicate artist IDs and schedule EnrichDiscographyWorker per unknown artist
  """

  use PremiereEcouteCore.Worker, queue: :discography, max_attempts: 3

  require Logger

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Workers.EnrichDiscographyWorker
  alias PremiereEcoute.Radio.RadioTrack

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    yesterday = Date.add(Date.utc_today(), -1)

    track_ids =
      yesterday
      |> RadioTrack.distinct_provider_ids(:spotify)
      |> Enum.reject(&already_known?/1)

    artist_ids =
      track_ids
      |> Enum.flat_map(&resolve_artist_id/1)
      |> Enum.uniq()

    Enum.each(artist_ids, fn artist_id ->
      EnrichDiscographyWorker.now(%{"spotify_id" => artist_id})
    end)

    Logger.info(
      "radio discography sync #{Date.to_string(yesterday)}: #{length(track_ids)} unknown tracks, #{length(artist_ids)} artists scheduled"
    )

    :ok
  end

  defp already_known?(spotify_track_id) do
    not is_nil(Album.Track.find_by_provider(spotify_track_id, :spotify))
  end

  defp resolve_artist_id(spotify_track_id) do
    case Apis.spotify().get_track(spotify_track_id) do
      {:ok, %Album.Track{artist_spotify_id: id}} when is_binary(id) -> [id]
      _ -> []
    end
  end
end
