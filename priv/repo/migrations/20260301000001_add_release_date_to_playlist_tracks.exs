defmodule PremiereEcoute.Repo.Migrations.AddReleaseDateToPlaylistTracks do
  use Ecto.Migration

  def change do
    alter table(:playlist_tracks) do
      add_if_not_exists :release_date, :date
    end
  end
end
