defmodule PremiereEcoute.Repo.Migrations.CreateSessionNotes do
  use Ecto.Migration

  def change do
    create table(:session_notes) do
      add :content, :text, null: false

      add :listening_session_id, references(:listening_sessions, on_delete: :delete_all),
        null: false

      add :track_marker_id, references(:track_markers, on_delete: :nilify_all), null: true

      timestamps(type: :utc_datetime)
    end

    create index(:session_notes, [:listening_session_id])
  end
end
