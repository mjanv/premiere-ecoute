defmodule PremiereEcoute.Repo.Migrations.CreateUsersOauthTokens do
  use Ecto.Migration

  def change do
    create table(:user_oauth_tokens) do
      add :provider, :string, null: false
      add :user_id, :string, null: false
      add :username, :string, null: false
      add :access_token, :binary
      add :refresh_token, :binary
      add :expires_at, :utc_datetime

      add :parent_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:user_oauth_tokens, [:user_id, :provider],
             name: :unique_user_provider_tokens
           )
  end
end
