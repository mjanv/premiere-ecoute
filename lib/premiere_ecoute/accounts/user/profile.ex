defmodule PremiereEcoute.Accounts.User.Profile do
  @moduledoc """
  User profile settings.

  Embedded schema for user preferences including color scheme (light/dark/system), language (en/fr/it),
  and two widget colors (hex strings) used in OBS overlay displays.
  """

  use PremiereEcouteCore.Aggregate.Object

  @schemes [:light, :dark, :system]
  @languages [:en, :fr, :it]
  @default_color1 "#5b21b6"
  @default_color2 "#be123c"
  @hex_color_regex ~r/^#[0-9A-Fa-f]{6}$/

  @type t :: %__MODULE__{
          color_scheme: :light | :dark | :system,
          language: :en | :fr | :it,
          timezone: String.t(),
          widget_color1: String.t(),
          widget_color2: String.t(),
          radio_settings: map() | nil
        }

  embedded_schema do
    field :color_scheme, Ecto.Enum, values: @schemes, default: :system
    field :language, Ecto.Enum, values: @languages, default: :en
    field :timezone, :string, default: "UTC"
    field :widget_color1, :string, default: @default_color1
    field :widget_color2, :string, default: @default_color2

    embeds_one :radio_settings, RadioSettings, on_replace: :update, primary_key: false do
      field :enabled, :boolean, default: false
      field :retention_days, :integer, default: 7
      field :visibility, Ecto.Enum, values: [:private, :public], default: :public
    end
  end

  def get(user, path, default \\ nil) do
    Enum.reduce_while(path, user.profile, fn key, acc ->
      case acc do
        nil -> {:halt, default}
        _ -> {:cont, Map.get(acc, key, default)}
      end
    end)
  end

  @doc "User profile changeset."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(profile, attrs \\ %{}) do
    profile = %{profile | radio_settings: profile.radio_settings || %__MODULE__.RadioSettings{}}

    profile
    |> cast(attrs, [:color_scheme, :language, :timezone, :widget_color1, :widget_color2])
    |> cast_embed(:radio_settings, with: &radio_settings_changeset/2)
    |> validate_required([:color_scheme, :language])
    |> validate_inclusion(:color_scheme, @schemes)
    |> validate_inclusion(:language, @languages)
    |> validate_timezone()
    |> validate_format(:widget_color1, @hex_color_regex, message: "must be a valid hex color (e.g. #a1b2c3)")
    |> validate_format(:widget_color2, @hex_color_regex, message: "must be a valid hex color (e.g. #a1b2c3)")
  end

  defp radio_settings_changeset(settings, attrs) do
    settings
    |> cast(attrs, [:enabled, :retention_days, :visibility])
    |> validate_number(:retention_days, greater_than: 0)
  end

  defp validate_timezone(changeset) do
    validate_change(changeset, :timezone, fn :timezone, tz ->
      if PremiereEcouteCore.Timezone.exists?(tz), do: [], else: [timezone: "is not a valid timezone"]
    end)
  end
end
