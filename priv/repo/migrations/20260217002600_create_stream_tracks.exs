defmodule PremiereEcoute.Repo.Migrations.CreateStreamTracks do
  use Ecto.Migration

  def change do
    create table(:radio_tracks) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      # Track metadata (denormalized from Spotify API)
      add :provider_id, :string, null: false
      add :name, :string, null: false
      add :artist, :string, null: false
      add :album, :string
      add :duration_ms, :integer

      # Playback detection timestamp
      add :started_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:radio_tracks, [:user_id, :started_at])
    create index(:radio_tracks, [:started_at])
  end
end
