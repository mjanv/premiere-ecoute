defmodule PremiereEcouteWeb.Oauth.ResourceOwners do
  @moduledoc """
  Boruta `Boruta.Oauth.ResourceOwners` implementation.

  Bridges Boruta's authorization server to our existing `PremiereEcoute.Accounts.User`,
  so OAuth access tokens (e.g. issued to the claude.ai MCP connector) are bound to a real
  application user instead of a separate OAuth-only identity.
  """

  @behaviour Boruta.Oauth.ResourceOwners

  alias Boruta.Oauth.ResourceOwner
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo

  @impl Boruta.Oauth.ResourceOwners
  def get_by(sub: sub) do
    case Repo.get(User, sub) do
      nil -> {:error, "User not found."}
      user -> {:ok, to_resource_owner(user)}
    end
  end

  def get_by(username: username) do
    case User.get_user_by_email(username) do
      nil -> {:error, "User not found."}
      user -> {:ok, to_resource_owner(user)}
    end
  end

  @impl Boruta.Oauth.ResourceOwners
  def check_password(_resource_owner, _password), do: {:error, "Password authentication is not supported."}

  @impl Boruta.Oauth.ResourceOwners
  def authorized_scopes(%ResourceOwner{}), do: []

  @impl Boruta.Oauth.ResourceOwners
  def claims(%ResourceOwner{sub: sub}, _scope) do
    case Repo.get(User, sub) do
      nil -> %{}
      user -> %{sub: sub, preferred_username: user.username, email: user.email}
    end
  end

  defp to_resource_owner(%User{} = user) do
    %ResourceOwner{
      sub: to_string(user.id),
      username: user.email,
      last_login_at: user.authenticated_at
    }
  end
end
