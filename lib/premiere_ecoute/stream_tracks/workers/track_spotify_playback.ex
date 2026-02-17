defmodule PremiereEcoute.StreamTracks.Workers.TrackSpotifyPlayback do
  @moduledoc """
  Oban worker for tracking Spotify playback during streams.

  Polls Spotify Player API every 60 seconds to detect currently playing tracks
  and stores them in the stream_tracks table. Self-schedules next poll after
  successful execution.
  """

  # AIDEV-NOTE: Self-scheduling worker - starts on stream.online, stops when feature disabled or stream offline
  # AIDEV-NOTE: Handles rate limits (5-min backoff), consecutive duplicates, and graceful degradation

  use PremiereEcouteCore.Worker, queue: :spotify, max_attempts: 3

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Player
  alias PremiereEcoute.StreamTracks

  @impl true
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    user = Accounts.User.get!(user_id)
    scope = Scope.for_user(user)

    with true <- feature_enabled?(user),
         {:ok, playback} <- Apis.spotify().get_playback_state(scope, Player.default()),
         {:ok, _track} <- store_track_if_new(user_id, playback),
         :ok <- schedule_next_poll(user_id) do
      :ok
    else
      false ->
        Logger.debug("Stream track tracking disabled for user #{user_id}")
        :ok

      {:error, "Spotify rate limit exceeded"} ->
        Logger.warning("Rate limit hit for user #{user_id}, backing off for 5 minutes")
        __MODULE__.in_seconds(%{user_id: user_id}, 300)
        :ok

      {:error, :consecutive_duplicate} ->
        # Same track still playing, schedule next poll
        schedule_next_poll(user_id)
        :ok

      {:error, :no_track_playing} ->
        # No track playing, schedule next poll
        schedule_next_poll(user_id)
        :ok

      {:error, reason} ->
        Logger.error("Playback tracking failed for user #{user_id}: #{inspect(reason)}")
        :ok
    end
  end

  defp feature_enabled?(user) do
    case user.profile.stream_track_settings do
      %{enabled: true} -> true
      _ -> false
    end
  end

  defp store_track_if_new(_user_id, %{"item" => nil}), do: {:error, :no_track_playing}

  defp store_track_if_new(user_id, %{"item" => %{"id" => provider_id}} = playback) do
    StreamTracks.insert_track(user_id, %{
      provider_id: provider_id,
      name: get_in(playback, ["item", "name"]),
      artist: get_in(playback, ["item", "artists"]) |> List.first() |> Map.get("name"),
      album: get_in(playback, ["item", "album", "name"]),
      duration_ms: get_in(playback, ["item", "duration_ms"]),
      started_at: DateTime.utc_now()
    })
  end

  defp schedule_next_poll(user_id) do
    __MODULE__.in_seconds(%{user_id: user_id}, 60)
    :ok
  end
end
