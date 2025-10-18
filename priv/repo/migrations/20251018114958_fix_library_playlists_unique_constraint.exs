defmodule PremiereEcoute.Repo.Migrations.FixLibraryPlaylistsUniqueConstraint do
  use Ecto.Migration

  def change do
    # Drop the old unique index that prevented multiple users from adding the same playlist
    drop unique_index(:library_playlists, [:playlist_id, :provider])

    # Create new unique index that allows multiple users to add the same playlist
    create unique_index(:library_playlists, [:user_id, :playlist_id, :provider])
  end
end
