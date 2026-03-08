defmodule PremiereEcoute.Repo.Migrations.AddReplaysToListeningSessions do
  use Ecto.Migration

  def change do
    alter table(:listening_sessions) do
      add :replays, {:array, :map}, default: []
    end
  end
end
