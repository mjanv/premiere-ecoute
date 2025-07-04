defmodule PremiereEcoute.Apis.TwitchApi do
  @moduledoc "Twitch API"

  require Logger

  defmodule Behavior do
    @moduledoc false

    @callback create_poll(broadcaster_id :: String.t(), token :: String.t(), pool :: map()) ::
                {:ok, map()} | {:error, term()}

    @callback end_poll(broadcaster_id :: String.t(), token :: String.t(), poll_id :: String.t()) ::
                {:ok, map()} | {:error, term()}
  end

  @behaviour __MODULE__.Behavior
  # @app :premiere_ecoute
  # @web "https://api.twitch.tv/helix"
  # @accounts "https://id.twitch.tv/oauth2"

  defdelegate authorization_url, to: __MODULE__.Accounts
  defdelegate authorization_code(code), to: __MODULE__.Accounts
  defdelegate renew_token(refresh_token), to: __MODULE__.Accounts

  defdelegate subscribe(broadcaster_id, token, type, session_id), to: __MODULE__.EventSub

  defdelegate create_poll(broadcaster_id, token, poll), to: __MODULE__.Polls
  defdelegate end_poll(broadcaster_id, token, poll_id), to: __MODULE__.Polls
  defdelegate get_poll(broadcaster_id, token, poll_id), to: __MODULE__.Polls
end
