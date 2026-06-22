defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.Availability do
  @moduledoc """
  Spotify API availability service.

  Pings several independent Spotify Web API routes in parallel and reports per-route
  status. A single faulty route (e.g. search down while artists is up) must not be
  reported as a full outage, so each route is checked and aggregated independently.

  Goes through `PremiereEcoute.Apis.spotify/0` like the rest of the codebase, so it
  resolves to the configured implementation (real client or `SpotifyApi.Mock` in tests).

  Only routes backed by `SpotifyApi.Behaviour` callbacks are checked, so each one can be
  stubbed in tests. User-scoped routes (player, playlists) require a live user OAuth
  session and are out of scope for an unattended availability probe.
  """

  require Logger

  alias PremiereEcoute.Apis

  # AIDEV-NOTE: stable IDs from Spotify's own API reference examples, chosen so checks
  # don't depend on catalog content that could be taken down or renamed.
  @artist_id "0TnOYISbd1XYRBk9myaseg"
  @track_id "11dFghVXANMlKmJXsNCbNl"

  @routes [:search, :artists, :artist_albums, :tracks]

  @timeout 10_000

  @type route :: :search | :artists | :artist_albums | :tracks
  @type check_result :: :ok | {:error, term()}
  @type report :: %{
          status: :ok | :degraded | :down,
          checks: %{route() => check_result()},
          checked_at: DateTime.t()
        }

  @doc """
  Checks all main Spotify API routes and returns an aggregated availability report.

  Runs each route check concurrently so a slow or hanging route does not delay the
  others. Status is `:ok` when every route succeeds, `:down` when every route fails,
  and `:degraded` otherwise.
  """
  @spec check() :: report()
  def check do
    Logger.info("Spotify availability check started for routes: #{inspect(@routes)}")

    checks =
      @routes
      |> Task.async_stream(&{&1, check_route(&1)}, timeout: @timeout, on_timeout: :kill_task)
      |> Enum.map(fn
        {:ok, {route, result}} -> {route, result}
        {:exit, reason} -> {:unknown, {:error, reason}}
      end)
      |> Enum.into(%{})

    report = %{status: status(checks), checks: checks, checked_at: DateTime.utc_now()}

    log_report(report)

    report
  end

  defp status(checks) do
    results = Map.values(checks)

    cond do
      Enum.all?(results, &(&1 == :ok)) -> :ok
      Enum.all?(results, &match?({:error, _}, &1)) -> :down
      true -> :degraded
    end
  end

  defp log_report(%{status: :ok} = report) do
    Logger.info("Spotify availability check passed: #{inspect(report.checks)}")
  end

  defp log_report(%{status: status} = report) do
    Logger.warning("Spotify availability check #{status}: #{inspect(report.checks)}")
  end

  defp check_route(route) do
    started_at = System.monotonic_time(:millisecond)
    result = run_route(route)
    duration_ms = System.monotonic_time(:millisecond) - started_at

    case result do
      :ok ->
        Logger.info("Spotify route #{route} ok in #{duration_ms}ms")

      {:error, reason} ->
        Logger.warning("Spotify route #{route} failed in #{duration_ms}ms: #{inspect(reason)}")
    end

    result
  end

  defp run_route(:search) do
    with {:ok, _} <- Apis.spotify().search_albums("a"), do: :ok
  end

  defp run_route(:artists) do
    with {:ok, _} <- Apis.spotify().get_artist(@artist_id), do: :ok
  end

  defp run_route(:artist_albums) do
    with {:ok, _} <- Apis.spotify().get_artist_albums(@artist_id), do: :ok
  end

  defp run_route(:tracks) do
    with {:ok, _} <- Apis.spotify().get_single(@track_id), do: :ok
  end
end
