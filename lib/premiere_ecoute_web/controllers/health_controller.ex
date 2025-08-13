defmodule PremiereEcouteWeb.HealthController do
  use PremiereEcouteWeb, :controller

  def index(conn, _params) do
    # Simple health check - returns 200 OK with basic status
    conn
    |> put_status(:ok)
    |> json(%{status: "ok", timestamp: DateTime.utc_now()})
  end
end