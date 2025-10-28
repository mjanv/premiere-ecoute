defmodule PremiereEcoute.Repo.Migrations.AddVisibilityToListeningSessions do
  use Ecto.Migration

  def change do
    alter table(:listening_sessions) do
      add :visibility, :string, default: "private", null: false
    end

    create constraint(:listening_sessions, :visibility_must_be_valid,
             check: "visibility IN ('private', 'protected', 'public')"
           )
  end
end
