defmodule PremiereEcoute.Repo.Migrations.AddProviderIdsToDiscography do
  use Ecto.Migration

  # AIDEV-NOTE: migrates albums, album_tracks, singles from (provider, album_id/track_id)
  # to a provider_ids JSONB map. Data is migrated before the old columns are dropped.

  def up do
    # --- albums ---
    alter table(:albums) do
      add :provider_ids, :map, default: %{}
    end

    flush()

    execute("""
    UPDATE albums
    SET provider_ids = json_build_object(provider::text, album_id)
    WHERE provider IS NOT NULL AND album_id IS NOT NULL
    """)

    drop unique_index(:albums, [:album_id, :provider])

    alter table(:albums) do
      remove :provider
      remove :album_id
    end

    create index(:albums, [:provider_ids], using: :gin)

    # --- album_tracks ---
    alter table(:album_tracks) do
      add :provider_ids, :map, default: %{}
    end

    flush()

    execute("""
    UPDATE album_tracks
    SET provider_ids = json_build_object(provider::text, track_id)
    WHERE provider IS NOT NULL AND track_id IS NOT NULL
    """)

    drop unique_index(:album_tracks, [:track_id, :provider])

    alter table(:album_tracks) do
      remove :provider
      remove :track_id
    end

    create index(:album_tracks, [:provider_ids], using: :gin)

    # --- singles ---
    alter table(:singles) do
      add :provider_ids, :map, default: %{}
    end

    flush()

    execute("""
    UPDATE singles
    SET provider_ids = json_build_object(provider::text, track_id)
    WHERE provider IS NOT NULL AND track_id IS NOT NULL
    """)

    drop unique_index(:singles, [:provider, :track_id])

    alter table(:singles) do
      remove :provider
      remove :track_id
    end

    create index(:singles, [:provider_ids], using: :gin)
  end

  def down do
    # --- albums ---
    drop index(:albums, [:provider_ids])

    alter table(:albums) do
      add :provider, :string
      add :album_id, :string
    end

    flush()

    execute("""
    UPDATE albums
    SET provider = (SELECT key FROM json_each_text(provider_ids::json) LIMIT 1),
        album_id = (SELECT value FROM json_each_text(provider_ids::json) LIMIT 1)
    """)

    alter table(:albums) do
      remove :provider_ids
    end

    create unique_index(:albums, [:album_id, :provider])

    # --- album_tracks ---
    drop index(:album_tracks, [:provider_ids])

    alter table(:album_tracks) do
      add :provider, :string
      add :track_id, :string
    end

    flush()

    execute("""
    UPDATE album_tracks
    SET provider = (SELECT key FROM json_each_text(provider_ids::json) LIMIT 1),
        track_id = (SELECT value FROM json_each_text(provider_ids::json) LIMIT 1)
    """)

    alter table(:album_tracks) do
      remove :provider_ids
    end

    create unique_index(:album_tracks, [:track_id, :provider])

    # --- singles ---
    drop index(:singles, [:provider_ids])

    alter table(:singles) do
      add :provider, :string
      add :track_id, :string
    end

    flush()

    execute("""
    UPDATE singles
    SET provider = (SELECT key FROM json_each_text(provider_ids::json) LIMIT 1),
        track_id = (SELECT value FROM json_each_text(provider_ids::json) LIMIT 1)
    """)

    alter table(:singles) do
      remove :provider_ids
    end

    create unique_index(:singles, [:provider, :track_id])
  end
end
