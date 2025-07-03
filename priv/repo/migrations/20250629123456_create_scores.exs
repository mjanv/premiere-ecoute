defmodule PremiereEcoute.Repo.Migrations.CreateScoreSystemTables do
  use Ecto.Migration

  def change do
    create table(:pools) do
      add :poll_id, :string, null: false
      add :title, :string
      add :total_votes, :integer, null: false, default: 0
      add :votes, :map, null: false, default: %{}
      add :ended_at, :naive_datetime

      add :session_id, references(:listening_sessions, on_delete: :delete_all), null: false
      add :track_id, references(:tracks, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:pools, [:poll_id])
    create unique_index(:pools, [:session_id, :track_id], name: :pools_session_track_index)
    create index(:pools, [:session_id])
    create index(:pools, [:track_id])

    create table(:reports) do
      add :generated_at, :naive_datetime, null: false
      add :individual_votes, :integer, null: false, default: 0
      add :pool_votes, :integer, null: false, default: 0
      add :unique_voters, :integer, null: false, default: 0
      add :session_summary, :map, null: false, default: %{}
      add :track_summaries, {:array, :map}, null: false, default: []

      add :session_id, references(:listening_sessions, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:reports, [:session_id])
    create index(:reports, [:generated_at])
  end
end
