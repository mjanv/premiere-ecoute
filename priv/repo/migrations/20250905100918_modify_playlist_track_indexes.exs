defmodule PremiereEcoute.Repo.Migrations.ModifyPlaylistTrackIndexes do
  use Ecto.Migration

  def change do
    # First drop the old unique index
    drop_if_exists unique_index(:playlist_tracks, [:track_id, :provider])

    # Then create the new one including playlist_id
    create unique_index(:playlist_tracks, [:playlist_id, :track_id, :provider])
  end
end
