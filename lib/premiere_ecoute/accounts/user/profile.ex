defmodule PremiereEcoute.Accounts.User.Profile do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  embedded_schema do
    field :display_name, :string
  end

  def changeset(profile, attrs \\ %{}) do
    profile
    |> cast(attrs, [:display_name])
    |> validate_required([:display_name])
  end
end
