defmodule PremiereEcoute.Repo.Migrations.CreateSingleArtists do
  use Ecto.Migration

  def change do
    create table(:single_artists, primary_key: false) do
      add :single_id, references(:singles, on_delete: :delete_all), null: false
      add :artist_id, references(:artists, on_delete: :delete_all), null: false
    end

    create unique_index(:single_artists, [:single_id, :artist_id])

    # AIDEV-NOTE: data migration — seed artists from distinct singles.artist values, then link singles
    execute """
            INSERT INTO artists (name, slug, inserted_at, updated_at)
            SELECT DISTINCT
              artist,
              lower(regexp_replace(artist, '[^a-zA-Z0-9]+', '-', 'g')),
              now(),
              now()
            FROM singles
            WHERE artist IS NOT NULL AND artist != ''
            ON CONFLICT (name) DO NOTHING
            """,
            ""

    execute """
            INSERT INTO single_artists (single_id, artist_id)
            SELECT s.id, ar.id
            FROM singles s
            JOIN artists ar ON ar.name = s.artist
            WHERE s.artist IS NOT NULL AND s.artist != ''
            ON CONFLICT DO NOTHING
            """,
            ""

    alter table(:singles) do
      remove :artist, :string
    end
  end
end
