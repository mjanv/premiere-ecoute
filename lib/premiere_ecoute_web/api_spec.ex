defmodule PremiereEcouteWeb.ApiSpec do
  @moduledoc """
  OpenAPI specification for the Premiere Ecoute REST API.
  """

  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server}
  alias PremiereEcouteWeb.{Endpoint, Router}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [Server.from_endpoint(Endpoint)],
      info: %Info{
        title: "Premiere Ecoute API",
        version: "1.0"
      },
      paths: Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{
          "bearer" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            description: "API token obtained from the application settings page"
          }
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
