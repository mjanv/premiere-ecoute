defmodule PremiereEcoute.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false, collate: :nocase
      add :role, :string, default: "viewer", null: false
      add :hashed_password, :string
      add :confirmed_at, :utc_datetime

      add :spotify_user_id, :string
      add :spotify_username, :string
      add :spotify_access_token, :string
      add :spotify_refresh_token, :string
      add :spotify_expires_at, :utc_datetime

      add :twitch_user_id, :string
      add :twitch_username, :string
      add :twitch_access_token, :string
      add :twitch_refresh_token, :string
      add :twitch_expires_at, :utc_datetime

      add :profile, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create constraint(:users, :role_must_be_valid,
             check: "role IN ('viewer', 'streamer', 'admin', 'bot')"
           )

    create unique_index(:users, [:email])
    execute("CREATE INDEX users_profile ON users USING GIN(profile)")

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
