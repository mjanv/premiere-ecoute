defmodule PremiereEcoute.Repo.Migrations.CreateReviewLikes do
  use Ecto.Migration

  def change do
    create table(:review_likes) do
      add :review_id, references(:reviews, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:review_likes, [:review_id])
    create unique_index(:review_likes, [:review_id, :user_id])
  end
end
