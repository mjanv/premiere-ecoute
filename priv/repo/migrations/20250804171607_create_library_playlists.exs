defmodule PremiereEcoute.Repo.Migrations.CreateLibraryPlaylists do
  use Ecto.Migration

  def change do
    create table(:user_library_playlists) do
      add :provider, :string, null: false
      add :playlist_id, :string, null: false
      add :url, :string, null: false

      add :title, :string, null: false
      add :description, :text
      add :cover_url, :string
      add :public, :boolean, default: true, null: false

      add :metadata, :map

      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:user_library_playlists, [:user_id])
    create unique_index(:user_library_playlists, [:provider, :playlist_id, :user_id])
  end
end
