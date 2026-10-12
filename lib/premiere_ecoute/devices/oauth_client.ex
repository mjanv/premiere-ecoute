defmodule PremiereEcoute.Devices.OauthClient do
  @moduledoc """
  OAuth client of the desktop player.

  A single public client (no secret) shipped inside the player: authorization code with PKCE, loopback redirect, restricted to the `player` scope.
  """

  alias Boruta.Ecto.Admin
  alias Boruta.Ecto.Client
  alias PremiereEcoute.Repo

  @id "6c1d8f0e-3a52-4b7e-9e41-2f5a7c9d8b13"

  @doc "Returns the public identifier of the player client."
  @spec id() :: String.t()
  def id, do: @id

  @doc "Creates the player client when it does not exist yet."
  @spec ensure!() :: Client.t()
  def ensure! do
    case Repo.get(Client, @id) do
      %Client{} = client ->
        client

      nil ->
        {:ok, client} =
          Admin.create_client(%{
            id: @id,
            name: "Premiere Ecoute Player",
            redirect_uris: ["http://127.0.0.1:*/cb"],
            supported_grant_types: ["authorization_code", "refresh_token", "revoke"],
            pkce: true,
            public_refresh_token: true,
            public_revoke: true,
            access_token_ttl: 3_600,
            authorize_scope: true,
            authorized_scopes: [%{name: "player"}]
          })

        client
    end
  end
end
