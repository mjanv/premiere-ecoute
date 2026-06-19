defmodule PremiereEcouteWeb.Schemas.SessionVoteRequest do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "SessionVoteRequest",
    type: :object,
    required: [:rating],
    properties: %{
      rating: %OpenApiSpex.Schema{type: :integer, minimum: 0, maximum: 10},
      username: %OpenApiSpex.Schema{type: :string, description: "Broadcaster username (required for viewers)"}
    }
  })
end
