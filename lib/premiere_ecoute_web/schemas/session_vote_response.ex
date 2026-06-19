defmodule PremiereEcouteWeb.Schemas.SessionVoteResponse do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "SessionVoteResponse",
    type: :object,
    properties: %{
      ok: %OpenApiSpex.Schema{type: :boolean, example: true},
      rating: %OpenApiSpex.Schema{type: :integer}
    }
  })
end
