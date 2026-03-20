defmodule PremiereEcoute.Repo.Migrations.CreateAutomationRuns do
  use Ecto.Migration

  def change do
    create table(:automation_runs) do
      add :automation_id, references(:playlist_automations, on_delete: :delete_all), null: false
      add :oban_job_id, :bigint, null: false
      add :status, :string, null: false
      add :trigger, :string, null: false
      add :steps, :map, null: false, default: "[]"
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:automation_runs, [:automation_id, :inserted_at])
  end
end
