defmodule PremiereEcoute.Repo.Migrations.CreateCollectionSessions do
  use Ecto.Migration

  def change do
    create table(:collection_sessions) do
      add :status, :string, null: false, default: "pending"
      add :current_index, :integer, null: false, default: 0
      add :kept, {:array, :string}, null: false, default: []
      add :rejected, {:array, :string}, null: false, default: []
      add :skipped, {:array, :string}, null: false, default: []

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
