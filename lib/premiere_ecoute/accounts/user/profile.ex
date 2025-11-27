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
          language: :en | :fr | :it
        }

  embedded_schema do
    field :color_scheme, Ecto.Enum, values: @schemes, default: :system
    field :language, Ecto.Enum, values: @languages, default: :en
  end

  @doc "User profile changeset."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(profile, attrs \\ %{}) do
    profile
    |> cast(attrs, [:color_scheme, :language])
    |> validate_required([:color_scheme, :language])
    |> validate_inclusion(:color_scheme, @schemes)
    |> validate_inclusion(:language, @languages)
  end
end
