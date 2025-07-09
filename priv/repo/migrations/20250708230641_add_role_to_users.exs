defmodule PremiereEcoute.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, default: "streamer", null: false
    end

    create constraint(:users, :role_must_be_valid, check: "role IN ('streamer', 'admin')")
  end
end
