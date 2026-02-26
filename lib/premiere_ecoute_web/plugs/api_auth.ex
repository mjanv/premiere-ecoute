defmodule PremiereEcouteWeb.Plugs.ApiAuth do
  @moduledoc """
  Plug for authenticating REST API requests via Bearer session tokens.

  Expects an `Authorization: Bearer <token>` header where the token is a valid
  user session token (same tokens used by the browser session, stored in user_tokens).
  On success, assigns `:current_scope` to the connection. On failure, halts with 401 JSON.
  """

  import Plug.Conn

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc """
  Validates the Bearer token and assigns the current scope, or halts with 401.
  """
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        authenticate(conn, token)

      _ ->
        unauthorized(conn, "Missing or invalid Authorization header")
    end
  end

  defp authenticate(conn, token) do
    case Accounts.get_user_by_api_token(token) do
      {user, _inserted_at} -> assign(conn, :current_scope, Scope.for_user(user))
      _ -> unauthorized(conn, "Invalid or expired token")
    end
  end

  defp unauthorized(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: message})
    |> halt()
  end
end
