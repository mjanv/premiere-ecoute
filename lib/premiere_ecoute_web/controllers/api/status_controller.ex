defmodule PremiereEcouteWeb.Api.StatusController do
  @moduledoc """
  API status endpoint.

  Smoke-test route that confirms authentication is working and returns
  basic information about the authenticated user.
  """

  use PremiereEcouteWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema

  operation(:index,
    summary: "API status",
    description:
      "Smoke-test route that confirms authentication is working and returns basic information about the authenticated user.",
    tags: ["Status"],
    security: [%{"bearer" => []}],
    responses: [
      ok:
        {"Status response", "application/json",
         %Schema{
           type: :object,
           properties: %{
             status: %Schema{type: :string, example: "ok"},
             user: %Schema{
               type: :object,
               properties: %{
                 id: %Schema{type: :integer},
                 username: %Schema{type: :string},
                 role: %Schema{type: :string}
               }
             },
             timestamp: %Schema{type: :string, format: :"date-time"}
           }
         }},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

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
