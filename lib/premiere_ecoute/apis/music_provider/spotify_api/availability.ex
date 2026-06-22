defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.Availability do
  @moduledoc """
  Spotify API availability checker.

  Pings several independent Spotify Web API routes in parallel and reports per-route
  status. A single faulty route (e.g. search down while albums is up) must not be
  reported as a full outage, so each route is checked and aggregated independently.

  Only routes reachable with the client-credentials token are checked: user-scoped
  routes (player, playlists) require a live user OAuth session and are out of scope
  for an unattended availability probe.
  """

  require Logger

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi

  # AIDEV-NOTE: stable IDs from Spotify's own API reference examples, chosen so checks
  # don't depend on catalog content that could be taken down or renamed.
  @album_id "4aawyAB9vmqN3uQ7FjRGTy"
  @artist_id "0TnOYISbd1XYRBk9myaseg"
  @track_id "11dFghVXANMlKmJXsNCbNl"

  @routes [:accounts, :search, :albums, :artists, :tracks]

  @timeout 10_000

  @type route :: :accounts | :search | :albums | :artists | :tracks
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
    checks =
      @routes
      |> Task.async_stream(&{&1, check_route(&1)}, timeout: @timeout, on_timeout: :kill_task)
      |> Enum.map(fn
        {:ok, {route, result}} -> {route, result}
        {:exit, _reason} -> nil
      end)
      |> Enum.into(%{})

    %{status: status(checks), checks: checks, checked_at: DateTime.utc_now()}
  end

  defp status(checks) do
    results = Map.values(checks)

    cond do
      Enum.all?(results, &(&1 == :ok)) -> :ok
      Enum.all?(results, &match?({:error, _}, &1)) -> :down
      true -> :degraded
    end
  end

  defp check_route(:accounts) do
    with {:ok, _} <- SpotifyApi.client_credentials(), do: :ok
  end

  defp check_route(:search) do
    with {:ok, _} <- SpotifyApi.search_albums("a"), do: :ok
  end

  defp check_route(:albums) do
    with {:ok, _} <- SpotifyApi.get_album(@album_id), do: :ok
  end

  defp check_route(:artists) do
    with {:ok, _} <- SpotifyApi.get_artist(@artist_id), do: :ok
  end

  defp check_route(:tracks) do
    with {:ok, _} <- SpotifyApi.get_track(@track_id), do: :ok
  end
end
