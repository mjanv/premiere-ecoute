defmodule PremiereEcoute.Repo.Migrations.CreateScoreSystemTables do
  use Ecto.Migration

  def change do
    create table(:polls) do
      add :poll_id, :string, null: false
      add :title, :string
      add :total_votes, :integer, null: false, default: 0
      add :votes, :map, null: false, default: %{}
      add :ended_at, :naive_datetime

      add :session_id, references(:listening_sessions, on_delete: :delete_all), null: false
      add :track_id, references(:album_tracks, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:polls, [:poll_id])
    create unique_index(:polls, [:session_id, :track_id], name: :polls_session_track_index)
    create index(:polls, [:session_id])
    create index(:polls, [:track_id])

    create table(:reports) do
      add :unique_votes, :integer, null: false, default: 0
      add :unique_voters, :integer, null: false, default: 0
      add :session_summary, :map, null: false, default: %{}
      add :track_summaries, {:array, :map}, null: false, default: []

      add :session_id, references(:listening_sessions, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:reports, [:session_id], name: :reports_session_id_unique_index)
  end
end
