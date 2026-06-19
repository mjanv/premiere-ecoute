defmodule PremiereEcouteWeb.Schemas.DecideRequest do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "DecideRequest",
    type: :object,
    required: [:decision],
    properties: %{
      decision: %OpenApiSpex.Schema{type: :string, enum: ["kept", "rejected", "skipped"]}
    }
  })
end
