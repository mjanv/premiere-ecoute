defmodule PremiereEcoute.Repo.Migrations.CreateUserNotifications do
  use Ecto.Migration

  def change do
    create table(:user_notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :data, :map, null: false, default: %{}
      add :read_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:user_notifications, [:user_id, :read_at, :inserted_at])
    create index(:user_notifications, [:user_id, :inserted_at])
  end
end
