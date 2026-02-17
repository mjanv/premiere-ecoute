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
          stream_track_settings: StreamTrackSettings.t() | nil
        }

  embedded_schema do
    field :color_scheme, Ecto.Enum, values: @schemes, default: :system
    field :language, Ecto.Enum, values: @languages, default: :en

    embeds_one :stream_track_settings, StreamTrackSettings, on_replace: :update do
      field :enabled, :boolean, default: false
      field :retention_days, :integer, default: 7
      field :visibility, Ecto.Enum, values: [:private, :public], default: :public
    end
  end

  @doc "User profile changeset."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(profile, attrs \\ %{}) do
    profile
    |> cast(attrs, [:color_scheme, :language])
    |> cast_embed(:stream_track_settings, with: &stream_track_settings_changeset/2)
    |> validate_required([:color_scheme, :language])
    |> validate_inclusion(:color_scheme, @schemes)
    |> validate_inclusion(:language, @languages)
  end

  defp stream_track_settings_changeset(settings, attrs) do
    settings
    |> cast(attrs, [:enabled, :retention_days, :visibility])
    |> validate_number(:retention_days, greater_than: 0)
  end
end
