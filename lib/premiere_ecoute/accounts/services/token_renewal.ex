defmodule PremiereEcoute.Accounts.Services.TokenRenewal do
  @moduledoc """
  API Token Manager

  Utility module for managing OAuth2 token renewal for provider APIs. Provides automatic token refresh functionality when tokens are approaching expiration, ensuring continuous API access for authenticated users without manual intervention.
  """

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis

  def maybe_renew_token(conn, provider) do
    with %Scope{user: %User{} = user} = scope <- conn.assigns[:current_scope],
         %{expires_at: expires_at, refresh_token: refresh_token} <- Map.get(user, provider),
         true <- token_expired?(expires_at),
         {:ok, tokens} <- Apis.provider(provider).renew_token(refresh_token),
         {:ok, user} <- User.refresh_token(user, provider, tokens) do
      %{scope | user: user}
    else
      {:error, reason} ->
        Logger.error("Failed to renew #{provider} token: #{inspect(reason)}")
        conn.assigns[:current_scope]

      _ ->
        conn.assigns[:current_scope]
    end
  end

  def token_expired?(nil), do: false
  def token_expired?(at), do: DateTime.compare(DateTime.utc_now(), DateTime.add(at, -300, :second)) == :gt
end
