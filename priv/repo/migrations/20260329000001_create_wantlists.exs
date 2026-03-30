defmodule PremiereEcoute.Repo.Migrations.CreateWantlists do
  use Ecto.Migration

  def change do
    create table(:wantlists) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:wantlists, [:user_id])

    create table(:wantlist_items) do
      add :type, :string, null: false
      add :album_id, references(:albums, on_delete: :delete_all)
      add :single_id, references(:singles, on_delete: :delete_all)
      add :artist_id, references(:artists, on_delete: :delete_all)
      add :wantlist_id, references(:wantlists, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:wantlist_items, [:wantlist_id])
    create unique_index(:wantlist_items, [:wantlist_id, :album_id], where: "album_id IS NOT NULL")

    create unique_index(:wantlist_items, [:wantlist_id, :single_id],
             where: "single_id IS NOT NULL"
           )

    create unique_index(:wantlist_items, [:wantlist_id, :artist_id],
             where: "artist_id IS NOT NULL"
           )
  end
end
