defmodule PremiereEcouteWeb.Plugs.ApiAuthOptional do
  @moduledoc """
  Plug that optionally authenticates REST API requests.

  Tries, in order:
  1. Browser session (already assigned by `fetch_current_scope_for_user`, including impersonation)
  2. Bearer API token from the Authorization header

  Does not halt on failure — leaves `:current_scope` unset if neither source succeeds.
  """

  import Plug.Conn

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc """
  Uses the browser session scope if present, then falls back to Bearer token auth.
  """
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case conn.assigns do
      %{current_scope: %Scope{user: user}} when not is_nil(user) ->
        # Browser session (or impersonation) already resolved the scope
        conn

      _ ->
        case get_req_header(conn, "authorization") do
          ["Bearer " <> token] -> authenticate_bearer(conn, token)
          _ -> conn
        end
    end
  end

  defp authenticate_bearer(conn, token) do
    case Accounts.get_user_by_api_token(token) do
      {user, _inserted_at} -> assign(conn, :current_scope, Scope.for_user(user))
      _ -> conn
    end
  end
end
