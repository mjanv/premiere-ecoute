defmodule PremiereEcoute.Repo.Migrations.CreateReviews do
  use Ecto.Migration

  def change do
    create table(:reviews) do
      add :role, :string, null: false
      add :watched_on, :date
      add :watched_before, :boolean, default: false, null: false
      add :content, :string, size: 5000, default: ""
      add :tags, {:array, :string}, default: []
      add :rating, :float, default: 0.0
      add :like, :boolean

      add :session_id, references(:listening_sessions, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:reviews, [:session_id])
    create index(:reviews, [:user_id])
    create unique_index(:reviews, [:session_id, :user_id])
  end
end
