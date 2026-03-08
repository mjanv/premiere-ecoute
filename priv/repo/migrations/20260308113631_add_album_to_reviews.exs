defmodule PremiereEcoute.Repo.Migrations.AddAlbumToReviews do
  use Ecto.Migration

  def up do
    alter table(:reviews) do
      add :album_id, references(:albums, on_delete: :delete_all), null: true
      modify :session_id, :integer, null: true
    end

    # Make role nullable for album-only reviews
    execute "ALTER TABLE reviews ALTER COLUMN role DROP NOT NULL"

    # Drop the old session-only unique index
    drop unique_index(:reviews, [:session_id, :user_id])

    # One review per user per session (when session-linked)
    create unique_index(:reviews, [:session_id, :user_id],
             where: "session_id IS NOT NULL",
             name: :reviews_session_id_user_id_index
           )

    # One review per user per album (when album-linked)
    create unique_index(:reviews, [:album_id, :user_id],
             where: "album_id IS NOT NULL",
             name: :reviews_album_id_user_id_index
           )

    create index(:reviews, [:album_id])

    # Enforce: at least one of session_id or album_id must be set
    create constraint(:reviews, :review_linked_to_session_or_album,
             check: "session_id IS NOT NULL OR album_id IS NOT NULL"
           )
  end

  def down do
    drop constraint(:reviews, :review_linked_to_session_or_album)
    drop index(:reviews, [:album_id])
    drop unique_index(:reviews, [:album_id, :user_id], name: :reviews_album_id_user_id_index)
    drop unique_index(:reviews, [:session_id, :user_id], name: :reviews_session_id_user_id_index)

    execute "ALTER TABLE reviews ALTER COLUMN role SET NOT NULL"

    alter table(:reviews) do
      remove :album_id
      modify :session_id, :integer, null: false
    end

    create unique_index(:reviews, [:session_id, :user_id])
  end
end
