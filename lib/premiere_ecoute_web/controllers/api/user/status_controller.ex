defmodule PremiereEcouteWeb.Api.User.StatusController do
  @moduledoc """
  API status endpoint.

  Smoke-test route that confirms authentication is working and returns
  basic information about the authenticated user.
  """

  use PremiereEcouteWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias PremiereEcouteWeb.Schemas

  operation(:index,
    summary: "API status",
    description:
      "Smoke-test route that confirms authentication is working and returns basic information about the authenticated user.",
    tags: ["Status"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer", "viewer"],
    responses: [
      ok: {"Status response", "application/json", Schemas.StatusResponse},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @doc "Returns the authenticated user's identity and a timestamp."
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(%{assigns: %{current_scope: %{user: user}}} = conn, _params) do
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
