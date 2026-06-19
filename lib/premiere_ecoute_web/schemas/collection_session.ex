defmodule PremiereEcouteWeb.Schemas.CollectionSession do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "CollectionSession",
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{type: :integer},
      status: %OpenApiSpex.Schema{type: :string, enum: ["pending", "active", "completed"]},
      current_index: %OpenApiSpex.Schema{type: :integer},
      kept_count: %OpenApiSpex.Schema{type: :integer},
      rejected_count: %OpenApiSpex.Schema{type: :integer},
      skipped_count: %OpenApiSpex.Schema{type: :integer}
    }
  })
end
