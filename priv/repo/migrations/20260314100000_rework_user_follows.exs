defmodule PremiereEcoute.Repo.Migrations.ReworkUserFollows do
  use Ecto.Migration

  def change do
    drop table(:user_follows)

    create table(:user_follows) do
      add :follower_id, references(:users, on_delete: :delete_all), null: false
      add :followed_id, references(:users, on_delete: :delete_all), null: false
      add :followed_at, :naive_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_follows, [:follower_id, :followed_id])
    create index(:user_follows, [:followed_id])
  end
end
