defmodule PremiereEcoute.Devices do
  @moduledoc """
  Desktop player of a user.

  One player per user. Enrollment is the OAuth login of the player client (`PremiereEcoute.Devices.OauthClient`); there is no device record, the access token identifies the user.
  """

  import Ecto.Query

  alias Boruta.Ecto.Token
  alias Boruta.Oauth.Token, as: OauthToken
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Devices.OauthClient
  alias PremiereEcoute.PubSub
  alias PremiereEcoute.Repo

  @doc """
  Revokes every access and refresh token the user's player holds.

  Tokens of other users and of other OAuth clients are left untouched. A connected player is told it was revoked (`"player:revoked:<user_id>"`).
  """
  @spec revoke_player(User.t()) :: :ok
  def revoke_player(%User{} = user) do
    user
    |> player_tokens()
    |> Enum.each(fn value ->
      with %OauthToken{} = token <- Boruta.AccessTokensAdapter.get_by(value: value) do
        Boruta.AccessTokensAdapter.revoke(token)
        Boruta.AccessTokensAdapter.revoke_refresh_token(token)
      end
    end)

    PubSub.broadcast("player:revoked:#{user.id}", :player_revoked)
  end

  @doc """
  Checks that the user's player can still refresh its tokens.
  """
  @spec player_enrolled?(User.t()) :: boolean()
  def player_enrolled?(%User{id: id}) do
    sub = to_string(id)
    client_id = OauthClient.id()

    Repo.exists?(
      from t in Token,
        where:
          t.client_id == ^client_id and t.sub == ^sub and t.type == "access_token" and
            not is_nil(t.refresh_token) and is_nil(t.refresh_token_revoked_at)
    )
  end

  defp player_tokens(%User{id: id}) do
    sub = to_string(id)
    client_id = OauthClient.id()

    Repo.all(from t in Token, where: t.client_id == ^client_id and t.sub == ^sub and t.type == "access_token", select: t.value)
  end
end
