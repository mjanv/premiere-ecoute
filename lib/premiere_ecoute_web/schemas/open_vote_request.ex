defmodule PremiereEcouteWeb.Schemas.OpenVoteRequest do
  @moduledoc false

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "OpenVoteRequest",
    type: :object,
    required: [:mode],
    properties: %{
      mode: %OpenApiSpex.Schema{type: :string, enum: ["viewer_vote", "duel", "streamer_choice"]},
      duration: %OpenApiSpex.Schema{type: :integer, description: "Vote duration in seconds", default: 60}
    }
  })
end
