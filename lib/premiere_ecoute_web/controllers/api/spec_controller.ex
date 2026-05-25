defmodule PremiereEcouteWeb.Api.SpecController do
  @moduledoc """
  Serves a role-filtered OpenAPI spec for authenticated users.

  Unauthenticated requests receive an empty spec.
  Authenticated requests receive a spec filtered to the user's role via `x-role` extensions.
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcouteWeb.ApiSpec
  alias PremiereEcouteWeb.OpenApiRoleFilter

  @doc "Returns the OpenAPI spec filtered to the current user's role."
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    spec =
      case conn.assigns[:current_scope] do
        %{user: %{role: role}} -> ApiSpec.spec() |> OpenApiRoleFilter.filter(role)
        _ -> %{ApiSpec.spec() | paths: %{}}
      end

    json(conn, spec)
  end
end
