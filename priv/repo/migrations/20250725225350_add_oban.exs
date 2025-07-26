defmodule PremiereEcoute.Repo.Migrations.AddOban do
  use Ecto.Migration

  use Ecto.Migration

  def up, do: Oban.Migration.up(prefix: "oban")

  def down, do: Oban.Migration.down(prefix: "oban", version: 1)
end
