defmodule PremiereEcoute.Accounts.User.Profile do
  @moduledoc false

  use PremiereEcoute.Core.Aggregate.Object

  @schemes [:light, :dark, :system]
  @languages [:en, :fr, :it]

  embedded_schema do
    field :color_scheme, Ecto.Enum, values: @schemes, default: :system
    field :language, Ecto.Enum, values: @languages, default: :en
  end

  def changeset(profile, attrs \\ %{}) do
    profile
    |> cast(attrs, [:color_scheme, :language])
    |> validate_required([:color_scheme, :language])
    |> validate_inclusion(:color_scheme, @schemes)
    |> validate_inclusion(:language, @languages)
  end
end
