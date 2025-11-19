defmodule PremiereEcoute.Repo.Migrations.CreateTrackMarkers do
  use Ecto.Migration

  def change do
    create table(:track_markers) do
      add :track_id, :integer, null: false
      add :track_number, :integer, null: false
      add :started_at, :utc_datetime, null: false

      add :listening_session_id, references(:listening_sessions, on_delete: :delete_all),
        null: false
    end

    create index(:track_markers, [:listening_session_id])
  end
end
