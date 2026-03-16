defmodule PremiereEcoute.Repo.Migrations.AddProviderIdsToArtists do
  use Ecto.Migration

  def change do
    alter table(:artists) do
      add :provider_ids, :map, default: %{}
    end

    create index(:artists, [:provider_ids], using: :gin)
  end
end
