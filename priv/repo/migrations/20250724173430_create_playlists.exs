defmodule PremiereEcoute.Repo.Migrations.CreatePlaylists do
  use Ecto.Migration

  def change do
    create table(:playlists) do
      add :spotify_id, :string, null: false
      add :name, :string, null: false
      add :spotify_owner_id, :string, null: false
      add :owner_name, :string, null: false
      add :cover_url, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:playlists, [:spotify_id])

    create table(:playlist_tracks) do
      add :spotify_id, :string, null: false
      add :album_spotify_id, :string, null: false
      add :user_spotify_id, :string, null: false
      add :name, :string, null: false
      add :artist, :string, null: false
      add :duration_ms, :integer, null: false
      add :added_at, :naive_datetime, null: false

      add :playlist_id, references(:playlists, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:playlist_tracks, [:playlist_id])
    create unique_index(:playlist_tracks, [:playlist_id, :spotify_id])
  end
end
