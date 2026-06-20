defmodule PremiereEcouteWeb.Schemas.ListeningSession do
  @moduledoc false

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ListeningSession",
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{type: :integer},
      status: %OpenApiSpex.Schema{type: :string, example: "started"},
      source: %OpenApiSpex.Schema{type: :string, enum: ["album", "playlist", "track"]},
      cover_url: %OpenApiSpex.Schema{type: :string, format: :uri, nullable: true},
      viewer_score: %OpenApiSpex.Schema{type: :number, nullable: true}
    }
  })
end
