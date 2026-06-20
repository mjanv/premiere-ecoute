defmodule PremiereEcouteWeb.Schemas.Wantlist do
  @moduledoc false

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Wantlist",
    type: :object,
    properties: %{
      items: %OpenApiSpex.Schema{
        type: :array,
        items: PremiereEcouteWeb.Schemas.WantlistItem
      }
    }
  })
end
