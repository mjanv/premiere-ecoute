defmodule PremiereEcoute.Repo.Migrations.RenameScheduleTypeAddScheduledAt do
  use Ecto.Migration

  def change do
    rename table(:playlist_automations), :schedule_type, to: :schedule

    alter table(:playlist_automations) do
      add :scheduled_at, :utc_datetime
    end
  end
end
