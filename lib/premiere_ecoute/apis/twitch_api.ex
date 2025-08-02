defmodule PremiereEcoute.Apis.TwitchApi do
  @moduledoc """
  # Twitch API Client

  Central client for Twitch API integration providing authentication, chat messaging, event subscriptions, and poll management functionality. This module acts as the main interface for all Twitch-related operations, delegating to specialized submodules for specific API domains while handling common concerns like authentication, request configuration, and telemetry.

  ## Accounts

  Handles OAuth2 authorization flow with Twitch, including generating authorization URLs, exchanging authorization codes for access tokens, and refreshing expired tokens. Manages both user and application access tokens with automatic token retrieval and caching.

  ## Chat

  Provides chat messaging capabilities for Twitch channels, including sending regular messages and announcements with color formatting. Messages are sent on behalf of authenticated users with appropriate channel permissions.

  ## EventSub

  Manages Twitch EventSub subscriptions for real-time event notifications. Supports subscribing to various event types, managing active subscriptions, and canceling subscriptions when no longer needed.

  ## Polls

  Facilitates Twitch poll creation and management, allowing broadcasters to create interactive polls, retrieve poll status, and end active polls. Polls enable audience engagement through voting mechanisms.
  """

  use PremiereEcoute.Core.Api, api: :twitch

  alias PremiereEcoute.Core.Cache
  alias PremiereEcoute.Telemetry
  alias PremiereEcoute.Telemetry.Apis.TwitchApiMetrics

  defmodule Behaviour do
    @moduledoc "Twitch API Behaviour"

    alias PremiereEcoute.Accounts.Scope
    alias PremiereEcoute.Accounts.User

    # Accounts
    @callback client_credentials() :: {:ok, map()} | {:error, any()}
    @callback authorization_url(scope :: String.t() | nil, state :: String.t() | nil) :: String.t()
    @callback authorization_code(code :: String.t()) :: {:ok, map()} | {:error, any()}
    @callback renew_token(refresh_token :: String.t()) :: {:ok, map()} | {:error, any()}

    # Chat
    @callback send_chat_message(scope :: Scope.t(), message :: String.t()) ::
                {:ok, map()} | {:error, term()}

    @callback send_chat_announcement(scope :: Scope.t(), message :: String.t(), color :: String.t()) ::
                {:ok, String.t()} | {:error, term()}

    # EventSub
    @callback get_event_subscriptions(scope :: Scope.t()) :: {:ok, [map()]} | {:error, term()}
    @callback subscribe(scope :: Scope.t(), type :: String.t()) :: {:ok, map()} | {:error, term()}
    @callback unsubscribe(scope :: Scope.t(), type :: String.t()) :: {:ok, String.t()} | {:error, term()}
    @callback cancel_all_subscriptions(scope :: Scope.t()) :: {:ok, [String.t()]} | {:error, term()}

    # Polls
    @callback create_poll(scope :: Scope.t(), poll :: map()) :: {:ok, map()} | {:error, term()}
    @callback end_poll(scope :: Scope.t(), poll_id :: String.t()) :: {:ok, map()} | {:error, term()}
    @callback get_poll(scope :: Scope.t(), poll_id :: String.t()) :: {:ok, map()} | {:error, term()}

    # Channels
    @callback get_followed_channels(scope :: Scope.t()) :: {:ok, [map()]} | {:error, term()}
    @callback get_followed_channel(scope :: Scope.t(), user :: User.t()) :: {:ok, map() | nil} | {:error, term()}
  end

  @spec api(:api | :accounts, String.t() | nil) :: Req.Request.t()
  def api(type, token \\ nil)

  def api(:api, token) do
    [
      base_url: url(:api),
      headers: [
        {"Authorization", "Bearer #{token(token)}"},
        {"Client-Id", Application.get_env(:premiere_ecoute, :twitch_client_id)},
        {"Content-Type", "application/json"}
      ]
    ]
    |> Keyword.merge(env(:twitch)[:req_options] || [])
    |> Req.new()
    |> Telemetry.ReqPipeline.attach(&TwitchApiMetrics.api_called/1)
  end

  def api(:accounts, _) do
    id = Application.get_env(:premiere_ecoute, :twitch_client_id)
    secret = Application.get_env(:premiere_ecoute, :twitch_client_secret)

    [
      base_url: url(:accounts),
      headers: [{"Content-Type", "application/x-www-form-urlencoded"}]
    ]
    |> Keyword.merge(env(:twitch)[:req_options] || [])
    |> Req.new()
    |> Req.Request.append_request_steps(
      body: fn request ->
        body = Map.merge(%{client_id: id, client_secret: secret}, request.body)
        %{request | body: URI.encode_query(body)}
      end
    )
    |> Telemetry.ReqPipeline.attach(&TwitchApiMetrics.api_called/1)
  end

  # Accounts
  defdelegate client_credentials, to: __MODULE__.Accounts
  defdelegate authorization_url(scope \\ nil, state \\ nil), to: __MODULE__.Accounts
  defdelegate authorization_code(code), to: __MODULE__.Accounts
  defdelegate renew_token(refresh_token), to: __MODULE__.Accounts

  # Chat
  defdelegate send_chat_message(scope, type), to: __MODULE__.Chat
  defdelegate send_chat_announcement(scope, type, color), to: __MODULE__.Chat

  # EventSub
  defdelegate get_event_subscriptions(scope), to: __MODULE__.EventSub
  defdelegate subscribe(scope, type), to: __MODULE__.EventSub
  defdelegate unsubscribe(scope, type), to: __MODULE__.EventSub
  defdelegate cancel_all_subscriptions(scope), to: __MODULE__.EventSub

  # Polls
  defdelegate create_poll(scope, poll), to: __MODULE__.Polls
  defdelegate end_poll(scope, poll_id), to: __MODULE__.Polls
  defdelegate get_poll(scope, poll_id), to: __MODULE__.Polls

  # Channels
  defdelegate get_followed_channels(scope), to: __MODULE__.Channels
  defdelegate get_followed_channel(scope, user), to: __MODULE__.Channels

  # Users
  defdelegate get_user(app_or_access_token), to: __MODULE__.Users
end
