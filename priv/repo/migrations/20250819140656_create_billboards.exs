defmodule PremiereEcoute.Repo.Migrations.CreateBillboards do
  use Ecto.Migration

  def change do
    create table(:billboards) do
      add :billboard_id, :string, null: false
      add :title, :string, null: false
      add :submissions, :jsonb, null: true, default: "[]"
      add :status, :string, null: false, default: "created"
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:billboards, [:billboard_id])
    create index(:billboards, [:user_id])

    execute("CREATE INDEX billboard_submissions ON billboards USING GIN(submissions)")
  end
end
