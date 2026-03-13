defmodule PremiereEcoute.Repo.Migrations.AddTrackSlugs do
  use Ecto.Migration

  def change do
    alter table(:album_tracks) do
      add :slug, :string
    end

    create index(:album_tracks, [:slug])
  end
end
