defmodule PremiereEcoute.Repo.Migrations.CreatePlaylistRules do
  use Ecto.Migration

  def change do
    create table(:playlist_rules) do
      add :rule_type, :string, null: false, default: "save_tracks"
      add :active, :boolean, null: false, default: true
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :library_playlist_id, references(:library_playlists, on_delete: :delete_all),
        null: false

      timestamps()
    end

    # Ensure only one active rule per user per rule_type
    create unique_index(:playlist_rules, [:user_id, :rule_type], where: "active = true")
    create index(:playlist_rules, [:user_id])
    create index(:playlist_rules, [:library_playlist_id])
  end
end
