defmodule PremiereEcoute.Repo.Migrations.CreatePodcasts do
  use Ecto.Migration

  def change do
    create table(:podcasts_shows) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :author, :string
      add :language, :string, null: false, default: "en"
      add :category, :string
      add :explicit, :boolean, null: false, default: false
      add :cover_key, :string
      add :published, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:podcasts_shows, [:user_id])
    create unique_index(:podcasts_shows, [:user_id, :slug])

    create table(:podcasts_episodes) do
      add :show_id, references(:podcasts_shows, on_delete: :delete_all), null: false
      add :guid, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :audio_key, :string
      add :audio_byte_size, :bigint
      add :duration_seconds, :integer
      add :status, :string, null: false, default: "uploading"
      add :published_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:podcasts_episodes, [:show_id])
    create unique_index(:podcasts_episodes, [:guid])
  end
end
