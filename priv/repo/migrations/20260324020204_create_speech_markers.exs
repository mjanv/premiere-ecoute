defmodule PremiereEcoute.Repo.Migrations.CreateSpeechMarkers do
  use Ecto.Migration

  def change do
    create table(:speech_markers) do
      add :started_at, :utc_datetime, null: false
      add :start_ms, :integer, null: false
      add :end_ms, :integer, null: false
      add :text, :string

      add :listening_session_id, references(:listening_sessions, on_delete: :delete_all),
        null: false
    end

    create index(:speech_markers, [:listening_session_id])
  end
end
