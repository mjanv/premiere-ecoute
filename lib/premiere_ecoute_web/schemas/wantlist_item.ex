defmodule PremiereEcouteWeb.Schemas.WantlistItem do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "WantlistItem",
    type: :object,
    properties: %{
      type: %OpenApiSpex.Schema{type: :string, enum: ["album", "track", "artist"]},
      name: %OpenApiSpex.Schema{type: :string},
      artist: %OpenApiSpex.Schema{type: :string, nullable: true},
      provider_ids: %OpenApiSpex.Schema{
        title: "ProviderIds",
        type: :object,
        description: "Provider IDs keyed by provider name (spotify, deezer, tidal)",
        additionalProperties: %OpenApiSpex.Schema{type: :string}
      }
    }
  })
end
