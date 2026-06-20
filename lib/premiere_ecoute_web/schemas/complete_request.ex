defmodule PremiereEcouteWeb.Schemas.CompleteRequest do
  @moduledoc false

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "CompleteRequest",
    type: :object,
    properties: %{
      remove_kept: %OpenApiSpex.Schema{type: :boolean, default: false, description: "Remove kept tracks from origin playlist"},
      remove_rejected: %OpenApiSpex.Schema{
        type: :boolean,
        default: false,
        description: "Remove rejected tracks from origin playlist"
      }
    }
  })
end
