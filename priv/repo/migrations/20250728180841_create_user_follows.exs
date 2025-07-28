defmodule PremiereEcoute.Repo.Migrations.CreateUserFollow do
  use Ecto.Migration

  def change do
    create table(:user_follows) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :streamer_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_follows, [:user_id, :streamer_id])
  end
end
