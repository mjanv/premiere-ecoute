defmodule PremiereEcouteWeb.HealthController do
  @moduledoc """
  Health check endpoint controller.

  Provides a simple health check endpoint returning status and timestamp for monitoring and uptime verification.
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Availability

  plug PremiereEcouteWeb.Plugs.SpotifyHealthRateLimit when action in [:spotify]

  @doc """
  Returns health check status with current timestamp.

  Responds with 200 OK status and JSON containing service health status and current UTC timestamp for monitoring systems.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{status: "ok", timestamp: DateTime.utc_now()})
  end

  @doc """
  Returns Spotify API availability across its main routes.

  Responds with 200 when all routes are healthy or only some are degraded, and 503 when
  every checked route is failing. Rate limited per IP since each call hits Spotify.
  """
  @spec spotify(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def spotify(conn, _params) do
    report = Availability.check()

    conn
    |> put_status(http_status(report.status))
    |> json(%{
      status: report.status,
      checked_at: report.checked_at,
      checks: Map.new(report.checks, fn {route, result} -> {route, check_json(result)} end)
    })
  end

  defp http_status(:down), do: :service_unavailable
  defp http_status(_), do: :ok

  defp check_json(:ok), do: "ok"
  defp check_json({:error, reason}), do: %{status: "error", reason: inspect(reason)}
end
