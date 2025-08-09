defmodule PremiereEcoute.Repo.Migrations.CreateLibraryPlaylists do
  use Ecto.Migration

  def change do
    create table(:library_playlists) do
      add :provider, :string, null: false
      add :playlist_id, :string, null: false

      add :title, :string, null: false
      add :description, :text
      add :url, :string, null: false
      add :cover_url, :string
      add :public, :boolean, default: true, null: false
      add :track_count, :integer, default: 0

      add :metadata, :map

      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:library_playlists, [:user_id])
    create unique_index(:library_playlists, [:playlist_id, :provider])
  end
end
