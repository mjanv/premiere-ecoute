defmodule PremiereEcoute.Repo.Migrations.AddAlbumSlugs do
  use Ecto.Migration

  def change do
    alter table(:albums) do
      add :slug, :string
    end

    create index(:albums, [:slug])
  end
end
