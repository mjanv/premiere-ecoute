defmodule PremiereEcoute.Repo.Migrations.AddProviderIdsUniqueIndexes do
  use Ecto.Migration

  # AIDEV-NOTE: enforces uniqueness of (provider, id) pairs in provider_ids JSONB
  # using partial expression indexes per provider — one row per album/track/single
  # per provider key is guaranteed unique.

  def up do
    execute(
      "CREATE UNIQUE INDEX albums_spotify_id_unique ON albums ((provider_ids->>'spotify')) WHERE provider_ids ? 'spotify'"
    )

    execute(
      "CREATE UNIQUE INDEX albums_deezer_id_unique ON albums ((provider_ids->>'deezer')) WHERE provider_ids ? 'deezer'"
    )

    execute(
      "CREATE UNIQUE INDEX album_tracks_spotify_id_unique ON album_tracks ((provider_ids->>'spotify')) WHERE provider_ids ? 'spotify'"
    )

    execute(
      "CREATE UNIQUE INDEX album_tracks_deezer_id_unique ON album_tracks ((provider_ids->>'deezer')) WHERE provider_ids ? 'deezer'"
    )

    execute(
      "CREATE UNIQUE INDEX singles_spotify_id_unique ON singles ((provider_ids->>'spotify')) WHERE provider_ids ? 'spotify'"
    )

    execute(
      "CREATE UNIQUE INDEX singles_deezer_id_unique ON singles ((provider_ids->>'deezer')) WHERE provider_ids ? 'deezer'"
    )
  end

  def down do
    execute("DROP INDEX IF EXISTS albums_spotify_id_unique")
    execute("DROP INDEX IF EXISTS albums_deezer_id_unique")
    execute("DROP INDEX IF EXISTS album_tracks_spotify_id_unique")
    execute("DROP INDEX IF EXISTS album_tracks_deezer_id_unique")
    execute("DROP INDEX IF EXISTS singles_spotify_id_unique")
    execute("DROP INDEX IF EXISTS singles_deezer_id_unique")
  end
end
