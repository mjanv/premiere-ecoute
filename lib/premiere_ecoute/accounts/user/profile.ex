defmodule PremiereEcoute.Accounts.User.Profile do
  @moduledoc """
  User profile settings.

  Embedded schema for user preferences including color scheme (light/dark/system) and language (en/fr/it).
  """

  use PremiereEcouteCore.Aggregate.Object

  @schemes [:light, :dark, :system]
  @languages [:en, :fr, :it]

  @type t :: %__MODULE__{
          color_scheme: :light | :dark | :system,
          language: :en | :fr | :it,
          timezone: String.t(),
          radio_settings: map() | nil
        }

  embedded_schema do
    field :color_scheme, Ecto.Enum, values: @schemes, default: :system
    field :language, Ecto.Enum, values: @languages, default: :en
    field :timezone, :string, default: "UTC"

    embeds_one :radio_settings, RadioSettings, on_replace: :update, primary_key: false do
      field :enabled, :boolean, default: false
      field :retention_days, :integer, default: 7
      field :visibility, Ecto.Enum, values: [:private, :public], default: :public
    end
  end

  @doc "User profile changeset."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(profile, attrs \\ %{}) do
    profile = %{profile | radio_settings: profile.radio_settings || %__MODULE__.RadioSettings{}}

    profile
    |> cast(attrs, [:color_scheme, :language, :timezone])
    |> cast_embed(:radio_settings, with: &radio_settings_changeset/2)
    |> validate_required([:color_scheme, :language])
    |> validate_inclusion(:color_scheme, @schemes)
    |> validate_inclusion(:language, @languages)
    |> validate_timezone()
  end

  defp radio_settings_changeset(settings, attrs) do
    settings
    |> cast(attrs, [:enabled, :retention_days, :visibility])
    |> validate_number(:retention_days, greater_than: 0)
  end

  defp validate_timezone(changeset) do
    validate_change(changeset, :timezone, fn :timezone, tz ->
      if Timex.Timezone.exists?(tz), do: [], else: [timezone: "is not a valid timezone"]
    end)
  end
end
