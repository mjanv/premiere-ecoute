defmodule PremiereEcoute.Accounts.User.Profile do
  @moduledoc false

  use PremiereEcouteCore.Aggregate.Object

  @schemes [:light, :dark, :system]
  @languages [:en, :fr, :it]

  # AIDEV-NOTE: overlay_color stores streamer's custom overlay color in hex format
  embedded_schema do
    field :color_scheme, Ecto.Enum, values: @schemes, default: :system
    field :language, Ecto.Enum, values: @languages, default: :en
    field :overlay_color, :string, default: "#9333ea"
  end

  def changeset(profile, attrs \\ %{}) do
    profile
    |> cast(attrs, [:color_scheme, :language, :overlay_color])
    |> validate_required([:color_scheme, :language])
    |> validate_inclusion(:color_scheme, @schemes)
    |> validate_inclusion(:language, @languages)
    |> validate_hex_color(:overlay_color)
  end

  # AIDEV-NOTE: Validates hex color format (#RRGGBB or #RGB)
  defp validate_hex_color(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      if is_nil(value) or value == "" or Regex.match?(~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/, value) do
        []
      else
        [{field, "must be a valid hex color (e.g., #9333ea)"}]
      end
    end)
  end
end
