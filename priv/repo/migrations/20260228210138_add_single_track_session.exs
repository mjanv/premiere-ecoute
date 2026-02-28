defmodule PremiereEcoute.Repo.Migrations.AddSingleTrackSession do
  use Ecto.Migration

  def change do
    create table(:singles) do
      add :provider, :string, null: false
      add :track_id, :string, null: false
      add :name, :string, null: false, size: 500
      add :artist, :string, null: false, size: 255
      add :duration_ms, :integer, default: 0
      add :cover_url, :string, size: 1000

      timestamps(type: :utc_datetime)
    end

    create unique_index(:singles, [:provider, :track_id])

    alter table(:listening_sessions) do
      modify :source, :string, default: "album", null: false
      add :single_id, references(:singles, on_delete: :restrict)
    end

    execute "UPDATE listening_sessions SET source = 'album' WHERE source NOT IN ('album', 'playlist', 'track')"
  end
end
