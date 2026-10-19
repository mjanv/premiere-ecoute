defmodule PremiereEcoute.Repo.Migrations.AddPlayerOauthClient do
  use Ecto.Migration

  alias PremiereEcoute.Devices.OauthClient

  def up do
    OauthClient.ensure!()
  end

  def down do
    execute("delete from oauth_clients where id = '#{OauthClient.id()}'")
  end
end
