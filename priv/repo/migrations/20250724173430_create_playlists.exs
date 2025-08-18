defmodule PremiereEcoute.Repo.Migrations.CreatePlaylists do
  use Ecto.Migration

  def change do
    create table(:playlists) do
      add :provider, :string, null: false
      add :playlist_id, :string, null: false

      add :owner_id, :string, null: false
      add :owner_name, :string, null: false

      add :title, :string, null: false
      add :description, :text
      add :url, :string, null: false
      add :cover_url, :string
      add :public, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:playlists, [:playlist_id, :provider])

    create table(:playlist_tracks) do
      add :provider, :string, null: false
      add :track_id, :string, null: false
      add :album_id, :string, null: false
      add :user_id, :string, null: false
      add :name, :string, null: false
      add :artist, :string, null: false
      add :duration_ms, :integer, null: false
      add :added_at, :naive_datetime, null: false
      add :release_date, :date, null: false

      add :playlist_id, references(:playlists, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:playlist_tracks, [:playlist_id])
    create unique_index(:playlist_tracks, [:track_id, :provider])
  end
end
