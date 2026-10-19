defmodule PremiereEcoute.Apis.Players.SpotifyProbe do
  @moduledoc """
  Oban worker probing Spotify player commands at stream start.

  Checks that music is playing, then pauses and resumes the current track at its saved position, logging one line per step. Used to monitor whether Spotify accepts player commands again for a streamer.
  """

  use PremiereEcouteCore.Worker, queue: :spotify, max_attempts: 1, unique: [period: 600, keys: [:user_id]]

  import Swoosh.Email

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Mailer
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Apis.Players.PlaybackState

  @step_delay_ms 2_000
  @snooze_seconds 30
  @deadline_seconds 8 * 60

  @impl true
  def perform(%Oban.Job{args: %{"user_id" => user_id} = args}) do
    delay = Map.get(args, "step_delay_ms", @step_delay_ms)

    with %User{} = user <- User.get(user_id),
         scope <- Accounts.maybe_renew_token(Scope.for_user(user), :spotify) do
      case Apis.spotify().get_playback_state(scope, PlaybackState.default()) do
        {:ok, %PlaybackState{is_playing: true} = state} ->
          log(user_id, "playing", :ok, state)
          probe(scope, user_id, state, delay)

        other ->
          if past_deadline?(args) do
            log(user_id, "playing", {:error, :not_playing}, nil)
            :ok
          else
            Logger.debug("[SpotifyProbe] user=#{user_id} waiting for playback: #{inspect(other)}")
            {:snooze, @snooze_seconds}
          end
      end
    else
      _ -> :ok
    end
  end

  defp past_deadline?(%{"started_at" => started_at}) do
    {:ok, started_at, _} = DateTime.from_iso8601(started_at)
    DateTime.diff(DateTime.utc_now(), started_at) >= @deadline_seconds
  end

  defp past_deadline?(_args), do: false

  defp probe(scope, user_id, state, delay) do
    pause = Apis.spotify().pause_playback(scope)
    log(user_id, "pause", pause, state)
    Process.sleep(delay)
    play = Apis.spotify().start_resume_playback(scope, state)
    log(user_id, "play", play, state)
    Process.sleep(delay)

    case Apis.spotify().get_playback_state(scope, PlaybackState.default()) do
      {:ok, %PlaybackState{is_playing: true}} -> log(user_id, "verify", :ok, state)
      other -> log(user_id, "verify", {:error, inspect(other)}, state)
    end

    if match?({:ok, _}, pause) and match?({:ok, _}, play), do: notify(user_id)

    :ok
  end

  defp notify(user_id) do
    user = User.get(user_id)

    new()
    |> to({"Maxime Janvier", "maxime.janvier@gmail.com"})
    |> from({"Premiere Ecoute", "hello@premiere-ecoute.fr"})
    |> subject("Spotify probe OK for #{user.username}")
    |> text_body("Pause and play commands both worked for #{user.username} at stream start.")
    |> Mailer.deliver()
  end

  defp log(user_id, step, result, state) do
    device = state && state.device

    {status, reason} =
      case result do
        :ok -> {"ok", nil}
        {:ok, _} -> {"ok", nil}
        {:error, reason} -> {"error", inspect(reason)}
      end

    Logger.info(
      "[SpotifyProbe] user=#{user_id} step=#{step} result=#{status} reason=#{inspect(reason)} device=#{device_label(device)}"
    )
  end

  defp device_label(%{name: name}), do: name
  defp device_label(_), do: "unknown"
end
