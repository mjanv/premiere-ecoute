defmodule PremiereEcouteWeb.Api.StatusController do
  @moduledoc """
  API status endpoint.

  Smoke-test route that confirms authentication is working and returns
  basic information about the authenticated user.
  """

  use PremiereEcouteWeb, :controller

  @doc """
  Returns the authenticated user's identity and a timestamp.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    user = conn.assigns.current_scope.user

    conn
    |> put_status(:ok)
    |> json(%{
      status: "ok",
      user: %{
        id: user.id,
        username: user.username,
        role: user.role
      },
      timestamp: DateTime.utc_now()
    })
  end
end
