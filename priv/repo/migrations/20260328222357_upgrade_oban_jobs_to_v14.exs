defmodule PremiereEcoute.Repo.Migrations.UpgradeObanJobsToV14 do
  use Ecto.Migration

  def up, do: Oban.Migrations.up(version: 14, prefix: "oban")

  def down, do: Oban.Migrations.down(version: 14, prefix: "oban")
end
