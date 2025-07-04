defmodule PremiereEcoute.Apis.TwitchApi do
  @moduledoc "Twitch API"

  defmodule Behavior do
    @moduledoc false

    alias PremiereEcoute.Accounts.Scope

    @callback subscribe(Scope.t(), type :: String.t()) :: {:ok, map()} | {:error, term()}

    @callback create_poll(Scope.t(), poll :: map()) :: {:ok, map()} | {:error, term()}
    @callback end_poll(Scope.t(), poll_id :: String.t()) :: {:ok, map()} | {:error, term()}
    @callback get_poll(Scope.t(), poll_id :: String.t()) :: {:ok, map()} | {:error, term()}
  end

  @behaviour __MODULE__.Behavior

  @app :premiere_ecoute
  # @web "https://api.twitch.tv/helix"
  # @accounts "https://id.twitch.tv/oauth2"

  def impl, do: Application.get_env(@app, :twitch_api, __MODULE__)

  def api(:helix, token \\ "") do
    Req.new(
      [
        base_url: "https://api.twitch.tv/helix",
        headers: [
          {"Authorization", "Bearer #{token}"},
          {"Client-Id", Application.get_env(:premiere_ecoute, :twitch_client_id)},
          {"Content-Type", "application/json"}
        ]
      ]
      |> Keyword.merge(Application.get_env(:premiere_ecoute, :twitch_req_options, []))
    )
  end

  defdelegate authorization_url, to: __MODULE__.Accounts
  defdelegate authorization_code(code), to: __MODULE__.Accounts
  defdelegate renew_token(refresh_token), to: __MODULE__.Accounts

  defdelegate subscribe(scope, type), to: __MODULE__.EventSub

  defdelegate create_poll(scope, poll), to: __MODULE__.Polls
  defdelegate end_poll(scope, poll_id), to: __MODULE__.Polls
  defdelegate get_poll(scope, poll_id), to: __MODULE__.Polls
end
