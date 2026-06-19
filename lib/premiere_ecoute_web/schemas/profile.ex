defmodule PremiereEcouteWeb.Schemas.Profile do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Profile",
    type: :object,
    properties: %{
      color_scheme: %OpenApiSpex.Schema{type: :string, enum: ["light", "dark", "system"]},
      language: %OpenApiSpex.Schema{type: :string, enum: ["en", "fr", "it"]},
      timezone: %OpenApiSpex.Schema{type: :string, example: "Europe/Paris"},
      widget_settings: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          color_primary: %OpenApiSpex.Schema{type: :string, pattern: "^#[0-9A-Fa-f]{6}$", example: "#5b21b6"},
          color_secondary: %OpenApiSpex.Schema{type: :string, pattern: "^#[0-9A-Fa-f]{6}$", example: "#be123c"}
        }
      },
      radio_settings: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          enabled: %OpenApiSpex.Schema{type: :boolean},
          retention_days: %OpenApiSpex.Schema{type: :integer, minimum: 1},
          visibility: %OpenApiSpex.Schema{type: :string, enum: ["private", "public"]}
        }
      }
    }
  })
end
