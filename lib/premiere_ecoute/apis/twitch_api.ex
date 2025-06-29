defmodule PremiereEcoute.Apis.TwitchApi do
  @moduledoc "Twitch API"

  require Logger

  defmodule Behavior do
    @moduledoc false

    @type poll_option :: %{text: String.t(), votes: integer()}
    @type poll_result :: %{
            id: String.t(),
            question: String.t(),
            options: [poll_option()],
            status: :active | :ended,
            total_votes: integer()
          }

    @callback authenticate_user(code :: String.t()) ::
                {:ok, %{user_id: String.t(), access_token: String.t()}} | {:error, term()}

    @callback create_poll(
                channel_id :: String.t(),
                question :: String.t(),
                options :: [String.t()]
              ) ::
                {:ok, String.t()} | {:error, term()}

    @callback end_poll(poll_id :: String.t()) ::
                {:ok, poll_result()} | {:error, term()}
  end

  @behaviour __MODULE__.Behavior
  # @app :premiere_ecoute
  # @web "https://api.twitch.tv/helix"
  # @accounts "https://id.twitch.tv/oauth2"

  defdelegate authorization_url, to: __MODULE__.Accounts
  defdelegate authorization_code(code), to: __MODULE__.Accounts

  defdelegate subscribe(broadcaster_id, token, type, session_id), to: __MODULE__.EventSub

  defdelegate create_poll(broadcaster_id, token, poll), to: __MODULE__.Polls
  defdelegate end_poll(broadcaster_id, token, poll_id), to: __MODULE__.Polls
  defdelegate get_poll(broadcaster_id, token, poll_id), to: __MODULE__.Polls
end
