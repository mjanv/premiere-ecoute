defmodule PremiereEcoute.Repo.Migrations.MakeDonationGoalIdNullable do
  use Ecto.Migration

  def change do
    alter table(:donations) do
      modify :goal_id, :bigint, null: true, from: {:bigint, null: false}
    end
  end
end
