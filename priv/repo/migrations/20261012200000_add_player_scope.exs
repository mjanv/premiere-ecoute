defmodule PremiereEcoute.Repo.Migrations.AddPlayerScope do
  use Ecto.Migration

  def up do
    execute("""
    insert into oauth_scopes (id, name, label, public, inserted_at, updated_at)
    values (gen_random_uuid(), 'player', 'Connect this PC as a player', false, now(), now())
    on conflict (name) do nothing
    """)
  end

  def down do
    execute("delete from oauth_scopes where name = 'player'")
  end
end
