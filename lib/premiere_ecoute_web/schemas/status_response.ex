defmodule PremiereEcouteWeb.Schemas.StatusResponse do
  @moduledoc false

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "StatusResponse",
    type: :object,
    properties: %{
      status: %OpenApiSpex.Schema{type: :string, example: "ok"},
      user: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          id: %OpenApiSpex.Schema{type: :integer},
          username: %OpenApiSpex.Schema{type: :string},
          role: %OpenApiSpex.Schema{type: :string}
        }
      },
      timestamp: %OpenApiSpex.Schema{type: :string, format: :"date-time"}
    }
  })
end
