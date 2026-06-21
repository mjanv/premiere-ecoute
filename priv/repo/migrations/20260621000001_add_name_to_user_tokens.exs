defmodule PremiereEcoute.Repo.Migrations.AddNameToUserTokens do
  use Ecto.Migration

  def change do
    alter table(:user_tokens) do
      add :name, :string
    end
  end
end
