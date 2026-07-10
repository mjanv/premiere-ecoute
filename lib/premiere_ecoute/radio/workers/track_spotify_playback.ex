defmodule PremiereEcoute.Radio.Workers.TrackSpotifyPlayback do
  @moduledoc """
  Oban worker for tracking Spotify playback during streams.

  Polls Spotify Player API every 60 seconds to detect currently playing tracks
  and stores them in the radio_tracks table. Self-schedules next poll after
  successful execution.
  """

  use PremiereEcouteCore.Worker, queue: :spotify, max_attempts: 3

  require Logger

  import Ecto.Query, only: [where: 3, from: 2]

  alias Oban.Job
  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Radio
  alias PremiereEcoute.Repo

  @worker "PremiereEcoute.Radio.Workers.TrackSpotifyPlayback"

  def next_in?(user_id) do
    query =
      from j in Oban.Job,
        where: j.state == "scheduled" and fragment("args->>'user_id' = ?", ^to_string(user_id)),
        order_by: [asc: j.scheduled_at],
        select: j.scheduled_at,
        limit: 1

    Repo.one(query, prefix: "oban")
  end

  def cancel_all(user_id) do
    Job
    |> where([j], j.worker == @worker and fragment("args->>'user_id' = ?", ^to_string(user_id)))
    |> Oban.cancel_all_jobs()
  end

  @impl true
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    with user <- user_id |> Accounts.User.get!() |> Repo.preload(:spotify),
         scope <- Accounts.maybe_renew_token(Scope.for_user(user), :spotify),
         {:enabled?, true} <- {:enabled?, Accounts.profile(user, [:radio_settings, :enabled], false)},
         {:ok, playback} <- Apis.cache(:spotify).get_playback_state(scope, PlaybackState.default()),
         {:ok, _track} <- store_track_if_new(user_id, playback),
         :ok <- schedule_next_poll(user_id, playback) do
      :ok
    else
      {:enabled?, false} ->
        Logger.info("[TrackSpotifyPlayback] user #{user_id}: radio disabled, not rescheduling")
        :ok

      {:error, "Spotify rate limit exceeded"} ->
        Logger.warning("[TrackSpotifyPlayback] user #{user_id}: rate limited, rescheduling in 300s")
        __MODULE__.in_seconds(%{user_id: user_id}, 300)
        :ok

      {:error, :consecutive_duplicate} ->
        Logger.info("[TrackSpotifyPlayback] user #{user_id}: consecutive duplicate, rescheduling (60s default)")
        schedule_next_poll(user_id)
        :ok

      {:error, :no_track_playing} ->
        Logger.info("[TrackSpotifyPlayback] user #{user_id}: no track playing, rescheduling (60s default)")
        schedule_next_poll(user_id)
        :ok

      {:error, reason} ->
        Logger.error("[TrackSpotifyPlayback] user #{user_id}: playback tracking failed (#{inspect(reason)}), rescheduling in 30s")
        # AIDEV-NOTE: reschedule after failure to keep loop alive (e.g. transient 401 on expired token)
        __MODULE__.in_seconds(%{user_id: user_id}, 30)
        :ok
    end
  rescue
    error ->
      Logger.error(
        "[TrackSpotifyPlayback] user #{user_id}: perform/1 raised #{Exception.format(:error, error, __STACKTRACE__)} — NOT rescheduling, job will retry/discard per Oban max_attempts"
      )

      reraise error, __STACKTRACE__
  end

  defp store_track_if_new(_user_id, %PlaybackState{item: nil}) do
    Logger.info("[TrackSpotifyPlayback] no track playing (nil item)")
    {:error, :no_track_playing}
  end

  defp store_track_if_new(user_id, %PlaybackState{item: %{uri: "spotify:track:" <> provider_id} = item, progress_ms: progress_ms}) do
    started_at =
      case progress_ms do
        ms when is_integer(ms) -> DateTime.add(DateTime.utc_now(), -ms, :millisecond)
        _ -> DateTime.utc_now()
      end

    result =
      Radio.insert_track(user_id, "spotify", %{
        provider_ids: %{spotify: provider_id},
        name: item.name,
        artist: item.artists |> List.first() |> then(&(&1 && Map.get(&1, :name))),
        album: nil,
        duration_ms: item.duration_ms,
        started_at: started_at
      })

    case result do
      {:ok, _track} ->
        Logger.info(
          "[TrackSpotifyPlayback] user #{user_id}: stored track #{inspect(item.name)} (duration_ms=#{item.duration_ms}, progress_ms=#{inspect(progress_ms)})"
        )

      {:error, :consecutive_duplicate} ->
        Logger.info(
          "[TrackSpotifyPlayback] user #{user_id}: skip duplicate #{inspect(item.name)} (duration_ms=#{item.duration_ms}, progress_ms=#{inspect(progress_ms)})"
        )

      {:error, reason} ->
        Logger.error("[TrackSpotifyPlayback] user #{user_id}: insert_track failed (#{inspect(reason)})")
    end

    result
  end

  defp store_track_if_new(user_id, %PlaybackState{item: %{uri: uri}}) do
    Logger.warning(
      "[TrackSpotifyPlayback] user #{user_id}: item with unrecognized uri #{inspect(uri)}, treating as no track playing"
    )

    {:error, :no_track_playing}
  end

  defp schedule_next_poll(user_id, playback \\ %PlaybackState{}) do
    delay_s =
      case playback do
        %PlaybackState{progress_ms: progress_ms, item: %{duration_ms: duration_ms}} when not is_nil(progress_ms) ->
          div(duration_ms - progress_ms + 30_000, 1000)

        _ ->
          60
      end

    Logger.info("[TrackSpotifyPlayback] user #{user_id}: scheduling next poll in #{delay_s}s")

    __MODULE__.in_seconds(%{user_id: user_id}, delay_s)
    :ok
  end
end
