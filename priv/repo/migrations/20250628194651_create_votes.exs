defmodule PremiereEcoute.Repo.Migrations.CreateVotes do
  use Ecto.Migration

  def change do
    create table(:votes) do
      add :viewer_id, :string, null: false
      add :track_id, :integer, null: false
      add :value, :string, null: false
      add :is_streamer, :boolean, default: false, null: false

      add :session_id, references(:listening_sessions, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:votes, [:session_id])
    create index(:votes, [:track_id])
    create unique_index(:votes, [:viewer_id, :session_id, :track_id], name: :vote_index)
  end
end
