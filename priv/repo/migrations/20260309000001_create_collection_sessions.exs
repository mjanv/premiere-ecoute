defmodule PremiereEcoute.Repo.Migrations.CreateCollectionSessions do
  use Ecto.Migration

  def change do
    create table(:collection_sessions) do
      add :status, :string, null: false, default: "pending"
      add :rule, :string, null: false, default: "ordered"
      add :selection_mode, :string, null: false, default: "streamer_choice"
      add :vote_duration, :integer
      add :current_index, :integer, null: false, default: 0

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :origin_playlist_id, references(:library_playlists, on_delete: :restrict), null: false

      add :destination_playlist_id, references(:library_playlists, on_delete: :restrict),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:collection_sessions, [:user_id])
    create index(:collection_sessions, [:origin_playlist_id])
    create index(:collection_sessions, [:destination_playlist_id])
  end
end
