defmodule PremiereEcoute.Radio.Workers.TrackSpotifyPlayback do
  @moduledoc """
  Oban worker for tracking Spotify playback during streams.

  Polls Spotify Player API every 60 seconds to detect currently playing tracks
  and stores them in the radio_tracks table. Self-schedules next poll after
  successful execution.
  """

  use PremiereEcouteCore.Worker, queue: :spotify, max_attempts: 3

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Radio

  @impl true
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    with %User{} = user <- User.get(user_id),
         scope <- Accounts.maybe_renew_token(Scope.for_user(user), :spotify),
         {:enabled?, true} <- {:enabled?, Accounts.profile(user, [:radio_settings, :enabled], false)},
         {:spotify?, {:ok, playback}} <- {:spotify?, Apis.cache(:spotify).get_playback_state(scope, PlaybackState.default())},
         {:track!, {:ok, _track}} <- {:track!, store_track_if_new(user_id, playback)} do
      schedule_next_poll(user_id, playback)
    else
      nil ->
        Logger.info("[#{__MODULE__}] user #{user_id}: no user found")
        :ok

      {:enabled?, false} ->
        Logger.info("[#{__MODULE__}] user #{user_id}: radio disabled")
        :ok

      {:spotify?, {:error, "Spotify rate limit exceeded"}} ->
        Logger.warning("[#{__MODULE__}] user #{user_id}: Spotify rate limit exceeded")
        schedule_next_poll(user_id, 300)

      {:spotify?, {:error, reason}} ->
        Logger.warning("[#{__MODULE__}] user #{user_id}: #{inspect(reason)}")
        schedule_next_poll(user_id, 60)

      {:track!, {:error, reason}} ->
        Logger.info("[#{__MODULE__}] user #{user_id}: #{inspect(reason)}")
        schedule_next_poll(user_id, 60)

      {:error, reason} ->
        Logger.error("[#{__MODULE__}] user #{user_id}: playback tracking failed (#{inspect(reason)})")
        schedule_next_poll(user_id, 60)
    end
  rescue
    error ->
      Logger.error("[#{__MODULE__}] user #{user_id}: raised #{Exception.message(error)}")
      reraise error, __STACKTRACE__
  end

  defp store_track_if_new(user_id, %PlaybackState{item: %{uri: "spotify:track:" <> provider_id} = item, progress_ms: progress_ms}) do
    user_id
    |> Radio.insert_track("spotify", %{
      provider_ids: %{spotify: provider_id},
      name: item.name,
      artist: item.artists |> List.first() |> then(&(&1 && Map.get(&1, :name))),
      album: nil,
      duration_ms: item.duration_ms,
      started_at:
        case progress_ms do
          ms when is_integer(ms) -> DateTime.add(DateTime.utc_now(), -ms, :millisecond)
          _ -> DateTime.utc_now()
        end
    })
    |> tap(fn
      {:ok, _track} ->
        Logger.info(
          "[#{__MODULE__}] user #{user_id}: stored track #{inspect(item.name)} (duration_ms=#{item.duration_ms}, progress_ms=#{inspect(progress_ms)})"
        )

      {:error, :consecutive_duplicate} ->
        Logger.info(
          "[#{__MODULE__}] user #{user_id}: skip duplicate #{inspect(item.name)} (duration_ms=#{item.duration_ms}, progress_ms=#{inspect(progress_ms)})"
        )

      {:error, reason} ->
        Logger.error("[#{__MODULE__}] user #{user_id}: insert_track failed (#{inspect(reason)})")
    end)
  end

  defp store_track_if_new(user_id, %PlaybackState{item: nil}) do
    Logger.info("[#{__MODULE__}] user #{user_id}: no track playing")
    {:error, :no_track_playing}
  end

  defp store_track_if_new(user_id, %PlaybackState{item: %{uri: uri}}) do
    Logger.warning("[#{__MODULE__}] user #{user_id}: unrecognized uri #{inspect(uri)}")
    {:error, :no_track_playing}
  end

  defp schedule_next_poll(user_id, delay) when is_integer(delay) do
    Logger.info("[#{__MODULE__}] user #{user_id}: scheduling next poll in #{delay}s")
    __MODULE__.in_seconds(%{user_id: user_id}, delay)
    :ok
  end

  defp schedule_next_poll(user_id, %PlaybackState{progress_ms: nil}) do
    delay = 60
    Logger.info("[#{__MODULE__}] user #{user_id}: scheduling next poll in #{delay}s")
    __MODULE__.in_seconds(%{user_id: user_id}, delay)
    :ok
  end

  defp schedule_next_poll(user_id, %PlaybackState{progress_ms: p, item: %{duration_ms: d}}) do
    delay = div(d - p + 30_000, 1_000)
    Logger.info("[#{__MODULE__}] user #{user_id}: scheduling next poll in #{delay}s")
    __MODULE__.in_seconds(%{user_id: user_id}, delay)
    :ok
  end
end
