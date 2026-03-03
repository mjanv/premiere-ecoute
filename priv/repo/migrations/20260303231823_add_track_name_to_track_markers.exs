defmodule PremiereEcoute.Repo.Migrations.AddTrackNameToTrackMarkers do
  use Ecto.Migration

  def change do
    alter table(:track_markers) do
      add :track_name, :string, null: true
    end
  end
end
