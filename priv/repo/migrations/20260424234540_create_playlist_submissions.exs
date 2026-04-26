defmodule PremiereEcoute.Repo.Migrations.CreatePlaylistSubmissions do
  use Ecto.Migration

  def up do
    create table(:library_playlist_submissions) do
      add :library_playlist_id, references(:library_playlists, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider_id, :string, null: false

      timestamps(updated_at: false)
    end

    create index(:library_playlist_submissions, [:library_playlist_id, :user_id])
    create index(:library_playlist_submissions, [:library_playlist_id, :provider_id])

    create unique_index(:library_playlist_submissions, [
             :library_playlist_id,
             :user_id,
             :provider_id
           ])
  end

  def down do
    drop table(:library_playlist_submissions)
  end
end
