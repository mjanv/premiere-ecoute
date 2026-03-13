defmodule PremiereEcoute.Repo.Migrations.CreateArtists do
  use Ecto.Migration

  def change do
    create table(:artists) do
      add :name, :string, null: false
      add :slug, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:artists, [:name])
    create index(:artists, [:slug])

    create table(:album_artists, primary_key: false) do
      add :album_id, references(:albums, on_delete: :delete_all), null: false
      add :artist_id, references(:artists, on_delete: :delete_all), null: false
    end

    create unique_index(:album_artists, [:album_id, :artist_id])

    # AIDEV-NOTE: data migration — seed artists from distinct album.artist values, then link albums
    execute """
            INSERT INTO artists (name, slug, inserted_at, updated_at)
            SELECT DISTINCT
              artist,
              lower(regexp_replace(artist, '[^a-zA-Z0-9]+', '-', 'g')),
              now(),
              now()
            FROM albums
            WHERE artist IS NOT NULL AND artist != ''
            ON CONFLICT (name) DO NOTHING
            """,
            ""

    execute """
            INSERT INTO album_artists (album_id, artist_id)
            SELECT a.id, ar.id
            FROM albums a
            JOIN artists ar ON ar.name = a.artist
            WHERE a.artist IS NOT NULL AND a.artist != ''
            ON CONFLICT DO NOTHING
            """,
            ""

    alter table(:albums) do
      remove :artist, :string
    end
  end
end
