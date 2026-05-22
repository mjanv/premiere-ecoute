defmodule PremiereEcoute.Repo.Migrations.CreatePlaylistSubscriptions do
  use Ecto.Migration

  def change do
    create table(:playlist_subscriptions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :library_playlist_id, references(:library_playlists, on_delete: :delete_all),
        null: false

      add :channels, {:array, :string}, null: false, default: ["email"]

      timestamps(updated_at: false)
    end

    create index(:playlist_subscriptions, [:library_playlist_id])
    create unique_index(:playlist_subscriptions, [:user_id, :library_playlist_id])
  end
end
