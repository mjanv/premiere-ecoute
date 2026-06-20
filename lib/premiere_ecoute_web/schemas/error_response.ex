defmodule PremiereEcouteWeb.Schemas.ErrorResponse do
  @moduledoc false

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ErrorResponse",
    type: :object,
    properties: %{
      error: %OpenApiSpex.Schema{type: :string}
    }
  })
end
