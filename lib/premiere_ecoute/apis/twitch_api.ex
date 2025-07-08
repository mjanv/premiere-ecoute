defmodule PremiereEcoute.Apis.TwitchApi do
  @moduledoc "Twitch API"

  require Logger

  alias PremiereEcoute.Telemetry
  alias PremiereEcoute.Telemetry.Apis.TwitchApiMetrics

  defmodule Behavior do
    @moduledoc false

    alias PremiereEcoute.Accounts.Scope

    # Chat
    @callback send_chat_message(Scope.t(), message :: String.t()) ::
                {:ok, map()} | {:error, term()}

    @callback send_chat_announcement(Scope.t(), message :: String.t(), color :: String.t()) ::
                {:ok, String.t()} | {:error, term()}

    # EventSub
    @callback get_event_subscriptions(Scope.t()) :: {:ok, [map()]} | {:error, term()}
    @callback subscribe(Scope.t(), type :: String.t()) :: {:ok, map()} | {:error, term()}
    @callback unsubscribe(Scope.t(), type :: String.t()) :: {:ok, String.t()} | {:error, term()}
    @callback cancel_all_subscriptions(Scope.t()) :: {:ok, [String.t()]} | {:error, term()}

    # Polls
    @callback create_poll(Scope.t(), poll :: map()) :: {:ok, map()} | {:error, term()}
    @callback end_poll(Scope.t(), poll_id :: String.t()) :: {:ok, map()} | {:error, term()}
    @callback get_poll(Scope.t(), poll_id :: String.t()) :: {:ok, map()} | {:error, term()}
  end

  @behaviour __MODULE__.Behavior

  @app :premiere_ecoute
  # @accounts "https://id.twitch.tv/oauth2"

  def impl, do: Application.get_env(@app, :twitch_api, __MODULE__)

  def api(:helix, token \\ nil) do
    token =
      with {:ok, nil} <- {:ok, token},
           {:ok, nil} <- Cachex.get(:tokens, :app_access_token),
           {:ok, token} <- PremiereEcoute.Apis.TwitchApi.Accounts.access_token() do
        token
      else
        {:ok, token} ->
          token

        {:error, reason} ->
          Logger.error("Cannot retrieve Twitch app access token due to #{inspect(reason)}")
          ""
      end

    Req.new(
      [
        base_url: "https://api.twitch.tv/helix",
        headers: [
          {"Authorization", "Bearer #{token}"},
          {"Client-Id", Application.get_env(@app, :twitch_client_id)},
          {"Content-Type", "application/json"}
        ]
      ]
      |> Keyword.merge(Application.get_env(@app, :twitch_req_options, []))
    )
    |> Telemetry.ReqPipeline.attach(&TwitchApiMetrics.api_called/1)
  end

  defdelegate authorization_url, to: __MODULE__.Accounts
  defdelegate authorization_code(code), to: __MODULE__.Accounts
  defdelegate renew_token(refresh_token), to: __MODULE__.Accounts

  defdelegate send_chat_message(scope, type), to: __MODULE__.Chat
  defdelegate send_chat_announcement(scope, type, color), to: __MODULE__.Chat

  defdelegate get_event_subscriptions(scope), to: __MODULE__.EventSub
  defdelegate subscribe(scope, type), to: __MODULE__.EventSub
  defdelegate unsubscribe(scope, type), to: __MODULE__.EventSub
  defdelegate cancel_all_subscriptions(scope), to: __MODULE__.EventSub

  defdelegate create_poll(scope, poll), to: __MODULE__.Polls
  defdelegate end_poll(scope, poll_id), to: __MODULE__.Polls
  defdelegate get_poll(scope, poll_id), to: __MODULE__.Polls
end
