defmodule PremiereEcouteWeb.Oauth.RegistrationController do
  @moduledoc """
  OAuth 2.0 Dynamic Client Registration (RFC 7591 / OpenID Connect Dynamic Client Registration 1.0).

  Lets remote MCP clients (e.g. claude.ai custom connectors) register themselves against
  `POST /oauth/register` without a human pre-creating a client, so adding the connector only
  requires the MCP server URL — no manually issued Client ID/Secret.
  """

  use PremiereEcouteWeb, :controller

  alias Boruta.Ecto.Admin

  require Logger

  # Boruta.Openid.register_client/3 both (a) pattern-matches `client_name`/
  # `token_endpoint_auth_method`/`jwks`/`jwks_uri` as ATOM keys to translate them (see
  # parse_registration_params/2 in deps/boruta/lib/boruta/openid.ex), and (b) hands the result to
  # Ecto.Changeset.cast/3, which rejects maps with mixed atom/string keys — so every recognized RFC
  # 7591 key must be atomized up front, not just the translated ones.
  @registration_keys ~w(
    client_name redirect_uris grant_types token_endpoint_auth_method jwks jwks_uri
    id name secret confidential access_token_ttl authorization_code_ttl refresh_token_ttl
    id_token_ttl authorize_scope supported_grant_types token_endpoint_auth_methods
    token_endpoint_jwt_auth_alg jwt_public_key pkce public_refresh_token public_revoke
    id_token_signature_alg id_token_kid userinfo_signed_response_alg logo_uri metadata
  )

  @doc """
  Registers a new OAuth client from the request body and returns its credentials.
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, registration_params) do
    params = build_registration_params(registration_params)
    conn = Plug.Conn.put_private(conn, :pkce_required, params[:token_endpoint_auth_method] == "none")

    Boruta.Openid.register_client(conn, drop_none_auth_method(params), __MODULE__)
  end

  defp build_registration_params(params) do
    params
    |> Map.take(@registration_keys)
    |> Map.new(fn {key, value} -> {String.to_existing_atom(key), value} end)
    |> rename_grant_types()
  end

  # RFC 7591's wire field is `grant_types`; Boruta.Ecto.Client's schema field is
  # `supported_grant_types` — Boruta.Openid only translates client_name/token_endpoint_auth_method/
  # jwks/jwks_uri, not this one, so it must be renamed here or the value is silently dropped by cast/3.
  defp rename_grant_types(%{grant_types: grant_types} = params) do
    params
    |> Map.delete(:grant_types)
    |> Map.put(:supported_grant_types, grant_types)
  end

  defp rename_grant_types(params), do: params

  # "none" (RFC 7591 §2 — no client authentication, e.g. PKCE public clients) is not a
  # member of Boruta.Ecto.Client's token_endpoint_auth_methods enum (basic/post/jwt variants only),
  # so it would fail registration_changeset's validate_subset. Drop it here; pkce gets granted
  # in client_registered/2 via a trusted post-create admin patch instead (see there for why).
  defp drop_none_auth_method(%{token_endpoint_auth_method: "none"} = params) do
    Map.delete(params, :token_endpoint_auth_method)
  end

  defp drop_none_auth_method(params), do: params

  def client_registered(conn, client) do
    maybe_grant_pkce(conn, client)

    conn
    |> put_status(:created)
    |> json(%{
      client_id: client.id,
      client_secret: client.secret,
      client_id_issued_at: System.system_time(:second),
      client_name: client.name,
      redirect_uris: client.redirect_uris,
      grant_types: client.supported_grant_types,
      token_endpoint_auth_method: client.token_endpoint_auth_methods
    })
  end

  # Boruta >= 2.3.7 fixed CVE-2026-65635 (over-privileged self-registered OAuth clients) by no
  # longer letting POST /oauth/register callers cast :pkce/:confidential/:supported_grant_types
  # (registration_changeset only casts a safe attribute subset — see @registration_attributes in
  # deps/boruta/lib/boruta/adapters/ecto/schemas/client.ex). "none"-auth clients (PKCE public
  # clients, e.g. claude.ai) still need pkce: true to complete their flow, so it's granted here via
  # Admin.update_client/2 (update_changeset, the authenticated/trusted path) right after creation —
  # never from caller-supplied params. `client` here is a Boruta.Oauth.Client (converted by
  # Boruta.Openid.register_client/3), not the Boruta.Ecto.Client that Admin.update_client/2 needs,
  # so the persisted record is re-fetched by id first.
  defp maybe_grant_pkce(%Plug.Conn{private: %{pkce_required: true}}, client) do
    ecto_client = Admin.get_client!(client.id)
    Admin.update_client(ecto_client, %{pkce: true})
  end

  defp maybe_grant_pkce(_conn, _client), do: :ok

  def registration_failure(conn, changeset) do
    Logger.warning("OAuth dynamic client registration failed: #{inspect(changeset.errors)}")

    conn
    |> put_status(:bad_request)
    |> json(%{error: "invalid_client_metadata", error_description: "Client registration parameters are invalid."})
  end
end
