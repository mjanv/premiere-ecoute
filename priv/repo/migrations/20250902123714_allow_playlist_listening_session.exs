defmodule PremiereEcoute.Repo.Migrations.AllowPlaylistListeningSession do
  use Ecto.Migration

  def change do
    execute "ALTER TABLE listening_sessions DROP CONSTRAINT listening_sessions_album_id_fkey"

    alter table(:listening_sessions) do
      add :source, :string, default: "album", null: false
      add :options, :map, default: %{}, null: false

      modify :album_id, references(:albums, on_delete: :nilify_all), null: true
      add :playlist_id, references(:playlists, on_delete: :delete_all)
      add :current_playlist_track_id, references(:playlist_tracks, on_delete: :nilify_all)
    end
  end
end
