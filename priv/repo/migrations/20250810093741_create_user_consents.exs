defmodule PremiereEcoute.Repo.Migrations.CreateUserConsents do
  use Ecto.Migration

  def change do
    create table(:user_consents) do
      add :document, :string, null: false
      add :version, :string, null: false
      add :accepted, :boolean, default: false, null: false

      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_consents, [:user_id])
    create index(:user_consents, [:document])
  end
end
