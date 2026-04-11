defmodule PremiereEcoute.Repo.Migrations.AddOptionsToCollectionSessions do
  use Ecto.Migration

  def change do
    alter table(:collection_sessions) do
      add :options, :map, null: false, default: %{}
    end
  end
end
