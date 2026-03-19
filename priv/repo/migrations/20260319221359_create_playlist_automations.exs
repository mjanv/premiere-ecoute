defmodule PremiereEcoute.Repo.Migrations.CreatePlaylistAutomations do
  use Ecto.Migration

  def change do
    create table(:playlist_automations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :enabled, :boolean, default: true, null: false
      add :schedule_type, :string, null: false
      add :cron_expression, :string
      add :steps, :map, null: false, default: "[]"

      timestamps(type: :utc_datetime)
    end

    create index(:playlist_automations, [:user_id])
  end
end
