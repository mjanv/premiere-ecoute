defmodule PremiereEcoute.Repo.Migrations.AddShareTokenToListeningSessions do
  use Ecto.Migration

  def change do
    alter table(:listening_sessions) do
      add :share_token, :string, null: false, default: ""
    end

    # AIDEV-NOTE: backfill BEFORE the unique index; builds slug-token from joined title + 8-char hex suffix
    execute(
      """
      WITH titles AS (
        SELECT
          ls.id,
          CASE ls.source
            WHEN 'album'    THEN a.name
            WHEN 'playlist' THEN p.title
            WHEN 'track'    THEN sg.name
            WHEN 'free'     THEN COALESCE(ls.name, 'free-session')
            ELSE 'session'
          END AS raw_title
        FROM listening_sessions ls
        LEFT JOIN albums    a  ON a.id  = ls.album_id
        LEFT JOIN playlists p  ON p.id  = ls.playlist_id
        LEFT JOIN singles   sg ON sg.id = ls.single_id
        WHERE ls.share_token = ''
      ),
      slugs AS (
        SELECT
          id,
          regexp_replace(
            regexp_replace(
              lower(raw_title),
              '[^a-z0-9]+', '-', 'g'
            ),
            '^-|-$', '', 'g'
          ) AS slug,
          substr(md5(id::text || random()::text), 1, 8) AS token
        FROM titles
      )
      UPDATE listening_sessions ls
      SET share_token = slugs.slug || '-' || slugs.token
      FROM slugs
      WHERE ls.id = slugs.id
      """,
      ""
    )

    create unique_index(:listening_sessions, [:share_token])
  end
end
