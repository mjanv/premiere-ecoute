defmodule PremiereEcoute.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false, collate: :nocase
      add :username, :string, null: false
      add :role, :string, default: "viewer", null: false
      add :hashed_password, :string
      add :confirmed_at, :utc_datetime

      add :profile, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create constraint(:users, :role_must_be_valid,
             check: "role IN ('viewer', 'streamer', 'admin', 'bot')"
           )

    create unique_index(:users, [:email])
    execute("CREATE INDEX user_profiles ON users USING GIN(profile)")

    create table(:user_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:user_tokens, [:user_id])
    create unique_index(:user_tokens, [:context, :token])
  end
end
