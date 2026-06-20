defmodule PremiereEcouteWeb.Schemas.CollectionVoteRequest do
  @moduledoc false

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "CollectionVoteRequest",
    type: :object,
    required: [:choice],
    properties: %{
      choice: %OpenApiSpex.Schema{type: :integer, enum: [1, 2], description: "1 for option A, 2 for option B"},
      username: %OpenApiSpex.Schema{type: :string, description: "Broadcaster username (required for viewers)"}
    }
  })
end
