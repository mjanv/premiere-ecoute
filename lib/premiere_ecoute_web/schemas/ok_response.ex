defmodule PremiereEcouteWeb.Schemas.OkResponse do
  @moduledoc false

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "OkResponse",
    type: :object,
    properties: %{
      ok: %OpenApiSpex.Schema{type: :boolean, example: true}
    }
  })
end
