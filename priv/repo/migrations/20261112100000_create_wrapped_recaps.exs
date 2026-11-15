defmodule PremiereEcoute.Repo.Migrations.CreateWrappedRecaps do
  use Ecto.Migration

  def change do
    create table(:wrapped_recaps) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :year, :integer, null: false
      add :cards, {:array, :map}, null: false, default: []
      add :share_token, :string, null: false
      add :version, :integer, null: false, default: 1
      add :computed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:wrapped_recaps, [:user_id, :year])
    create unique_index(:wrapped_recaps, [:share_token])
  end
end
