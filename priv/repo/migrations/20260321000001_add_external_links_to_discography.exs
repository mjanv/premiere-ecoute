defmodule PremiereEcoute.Repo.Migrations.AddExternalLinksToDiscography do
  use Ecto.Migration

  def change do
    alter table(:artists) do
      add :external_links, :map, default: %{}
    end

    alter table(:albums) do
      add :external_links, :map, default: %{}
    end

    alter table(:album_tracks) do
      add :external_links, :map, default: %{}
    end
  end
end
