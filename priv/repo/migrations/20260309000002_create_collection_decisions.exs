defmodule PremiereEcoute.Repo.Migrations.CreateCollectionDecisions do
  use Ecto.Migration

  def change do
    create table(:collection_decisions) do
      add :track_id, :string, null: false, size: 255
      add :track_name, :string, null: false, size: 500
      add :artist, :string, null: false, size: 255
      add :position, :integer, null: false
      add :decision, :string, null: false
      add :votes_a, :integer, null: false, default: 0
      add :votes_b, :integer, null: false, default: 0
      add :duel_track_id, :string, size: 255
      add :decided_at, :utc_datetime

      add :collection_session_id, references(:collection_sessions, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:collection_decisions, [:collection_session_id])
    create unique_index(:collection_decisions, [:collection_session_id, :track_id])
  end
end
