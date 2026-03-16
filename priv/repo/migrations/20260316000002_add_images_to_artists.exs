defmodule PremiereEcoute.Repo.Migrations.AddImagesToArtists do
  use Ecto.Migration

  def change do
    alter table(:artists) do
      add :images, {:array, :map}, default: []
    end
  end
end
