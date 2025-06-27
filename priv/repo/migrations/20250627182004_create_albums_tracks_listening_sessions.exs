defmodule PremiereEcoute.Repo.Migrations.CreateAlbumsTracksListeningSessions do
  use Ecto.Migration

  def change do
    # Albums table
    create table(:albums) do
      add :spotify_id, :string, null: false
      add :name, :string, null: false, size: 500
      add :artist, :string, null: false, size: 255
      add :release_date, :date
      add :cover_url, :string, size: 1000
      add :total_tracks, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:albums, [:spotify_id])

    # Tracks table
    create table(:tracks) do
      add :spotify_id, :string, null: false, size: 255
      add :name, :string, null: false, size: 500
      add :track_number, :integer, null: false
      add :duration_ms, :integer, default: 0
      add :preview_url, :string, size: 1000
      add :album_id, references(:albums, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:tracks, [:album_id])
    create unique_index(:tracks, [:spotify_id, :album_id])

    # Listening Sessions table
    create table(:listening_sessions) do
      add :streamer_id, :string, null: false
      add :album_id, :string
      add :current_track_id, :string
      add :status, :string, null: false, default: "preparing"
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all)
      add :album_spotify_id, :string
      add :current_track_spotify_id, :string

      timestamps(type: :utc_datetime)
    end

    create index(:listening_sessions, [:user_id])
    create index(:listening_sessions, [:album_spotify_id])
    create index(:listening_sessions, [:current_track_spotify_id])
    create index(:listening_sessions, [:status])

    # Add foreign key constraints
           )
  end
end
