defmodule PremiereEcoute.Repo.Migrations.AddFreeModeToListeningSessions do
  use Ecto.Migration

  def change do
    alter table(:listening_sessions) do
      add :name, :string, null: true
      add :vote_mode, :string, null: false, default: "chat"
    end

    execute "UPDATE listening_sessions SET source = source WHERE source NOT IN ('album', 'playlist', 'track', 'free')"
  end
end
