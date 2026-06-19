defmodule PremiereEcouteWeb.Schemas.OkResponse do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "OkResponse",
    type: :object,
    properties: %{
      ok: %OpenApiSpex.Schema{type: :boolean, example: true}
    }
  })
end
