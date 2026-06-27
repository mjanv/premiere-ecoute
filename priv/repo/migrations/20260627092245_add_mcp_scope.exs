defmodule PremiereEcoute.Repo.Migrations.AddMcpScope do
  use Ecto.Migration

  def up do
    execute("""
    insert into oauth_scopes (id, name, label, public, inserted_at, updated_at)
    values (gen_random_uuid(), 'mcp', 'Access the MCP server', true, now(), now())
    on conflict (name) do nothing
    """)
  end

  def down do
    execute("delete from oauth_scopes where name = 'mcp'")
  end
end
