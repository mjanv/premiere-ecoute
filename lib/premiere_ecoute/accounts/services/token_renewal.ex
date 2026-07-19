defmodule PremiereEcoute.Accounts.Services.TokenRenewal do
  @moduledoc """
  API Token Manager

  Utility module for managing OAuth2 token renewal for provider APIs. Provides automatic token refresh functionality when tokens are approaching expiration, ensuring continuous API access for authenticated users without manual intervention.
  """

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.OauthToken
  alias PremiereEcoute.Apis

  @doc """
  Automatically renews OAuth tokens when approaching expiration. Checks if the provider token expires within 5 minutes and refreshes it via the provider API if needed. Logs errors but returns the original scope on failure to avoid breaking the request flow.

  The actual read-refresh-write cycle is serialized per user/provider by
  `OauthToken.refresh_locked/4` to avoid a race where two concurrent renewals both
  use the same (about-to-be-rotated) refresh token, causing the loser to receive
  `invalid_grant` and disconnect an otherwise-healthy account. On a genuine
  `invalid_grant`, `refresh_locked/4` disconnects the provider itself and returns
  `{:ok, user}` with the provider cleared.
  """
  @spec maybe_renew_token(Scope.t(), atom()) :: Scope.t()
  def maybe_renew_token(scope, provider) do
    with %Scope{user: %User{} = user} <- scope,
         %{expires_at: expires_at} <- Map.get(user, provider),
         true <- token_expired?(expires_at) do
      renew_fun = fn refresh_token -> Apis.provider(provider).renew_token(refresh_token) end

      case OauthToken.refresh_locked(user, provider, &token_expired?/1, renew_fun) do
        {:ok, user} ->
          %{scope | user: user}

        {:error, reason} ->
          Logger.error("Failed to renew #{provider} token: #{inspect(reason)}")
          scope
      end
    else
      _error -> scope
    end
  end

  @doc """
  Checks if a token has expired or will expire within 5 minutes. Considers nil timestamps as non-expired to handle missing expiration data gracefully.
  """
  @spec token_expired?(DateTime.t() | nil) :: boolean()
  def token_expired?(nil), do: false
  def token_expired?(at), do: DateTime.compare(DateTime.utc_now(), DateTime.add(at, -300, :second)) == :gt
end
