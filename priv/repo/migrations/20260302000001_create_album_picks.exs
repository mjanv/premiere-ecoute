defmodule PremiereEcoute.Repo.Migrations.CreateAlbumPicks do
  use Ecto.Migration

  def change do
    create table(:album_picks) do
      add :album_id, :string, null: false, size: 255
      add :name, :string, null: false, size: 500
      add :artist, :string, null: false, size: 255
      add :cover_url, :string, size: 1000
      add :source, :string, null: false, default: "streamer"
      add :submitter, :string, size: 255

      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:album_picks, [:user_id])
    create unique_index(:album_picks, [:user_id, :album_id])
  end
end
