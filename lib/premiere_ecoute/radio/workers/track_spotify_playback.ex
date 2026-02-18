defmodule PremiereEcoute.Radio.Workers.TrackSpotifyPlayback do
  @moduledoc """
  Oban worker for tracking Spotify playback during streams.

  Polls Spotify Player API every 60 seconds to detect currently playing tracks
  and stores them in the radio_tracks table. Self-schedules next poll after
  successful execution.
  """

  # AIDEV-NOTE: Self-scheduling worker - starts on stream.online, stops when feature disabled or stream offline
  # AIDEV-NOTE: Handles rate limits (5-min backoff), consecutive duplicates, and graceful degradation

  use PremiereEcouteCore.Worker, queue: :spotify, max_attempts: 3

  require Logger

  alias PremiereEcoute.Accounts
  import Ecto.Query, only: [where: 3]

  alias Oban.Job
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Player
  alias PremiereEcoute.Radio

  def cancel_all(user_id) do
    worker = to_string(__MODULE__)

    Job
    |> where([j], j.worker == ^worker and fragment("args->>'user_id' = ?", ^to_string(user_id)))
    |> Oban.cancel_all_jobs()
  end

  @impl true
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    user = user_id |> Accounts.User.get!() |> Repo.preload(:spotify)
    scope = user |> Scope.for_user() |> then(&Accounts.maybe_renew_token(%{assigns: %{current_scope: &1}}, :spotify))

    with true <- feature_enabled?(user),
         {:ok, playback} <- Apis.spotify().get_playback_state(scope, Player.default()),
         {:ok, _track} <- store_track_if_new(user_id, playback),
         :ok <- schedule_next_poll(user_id, playback) do
      :ok
    else
      false ->
        Logger.debug("Radio tracking disabled for user #{user_id}")
        :ok

      {:error, "Spotify rate limit exceeded"} ->
        Logger.warning("Rate limit hit for user #{user_id}, backing off for 5 minutes")
        __MODULE__.in_seconds(%{user_id: user_id}, 300)
        :ok

      {:error, :consecutive_duplicate} ->
        schedule_next_poll(user_id)
        :ok

      {:error, :no_track_playing} ->
        schedule_next_poll(user_id)
        :ok

      {:error, reason} ->
        Logger.error("Playback tracking failed for user #{user_id}: #{inspect(reason)}")
        :ok
    end
  end

  defp feature_enabled?(user) do
    case user.profile.radio_settings do
      %{enabled: true} -> true
      _ -> false
    end
  end

  defp store_track_if_new(_user_id, %{"item" => nil}), do: {:error, :no_track_playing}

  defp store_track_if_new(user_id, %{"item" => %{"id" => provider_id}} = playback) do
    started_at =
      case playback["progress_ms"] do
        ms when is_integer(ms) -> DateTime.add(DateTime.utc_now(), -ms, :millisecond)
        _ -> DateTime.utc_now()
      end

    Radio.insert_track(user_id, %{
      provider_id: provider_id,
      name: get_in(playback, ["item", "name"]),
      artist: get_in(playback, ["item", "artists"]) |> List.first() |> Map.get("name"),
      album: get_in(playback, ["item", "album", "name"]),
      duration_ms: get_in(playback, ["item", "duration_ms"]),
      started_at: started_at
    })
  end

  defp schedule_next_poll(user_id, playback \\ %{}) do
    delay_s =
      case playback do
        %{"progress_ms" => progress_ms, "item" => %{"duration_ms" => duration_ms}}
        when is_integer(progress_ms) and is_integer(duration_ms) ->
          div(duration_ms - progress_ms + 30_000, 1000)

        _ ->
          60
      end

    __MODULE__.in_seconds(%{user_id: user_id}, delay_s)
    :ok
  end
end
