defmodule PremiereEcouteWeb.Mcp.Server do
  @moduledoc false

  alias Boruta.Oauth.Authorization.AccessToken
  alias Hermes.MCP.Error
  alias Hermes.Server.Frame
  alias Hermes.Server.Handlers
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Token
  alias PremiereEcoute.Repo
  alias PremiereEcouteWeb.Mcp.Components

  use Hermes.Server,
    name: "premiere-ecoute",
    version: "1.0.0",
    capabilities: [:tools, :resources, :prompts]

  component(Components.Profile)
  component(Components.Discography.Search.Album)
  component(Components.Discography.Search.Single)
  component(Components.Discography.Search.Artist)
  component(Components.Discography.Get.Album)
  component(Components.Wantlist.List)
  component(Components.Wantlist.Add)
  component(Components.Wantlist.Remove)
  component(Components.Wantlist.SaveCurrentTrack)
  component(Components.Prompts.AlbumReview)
  component(Components.Sessions.Active)
  component(Components.Sessions.Search)
  component(Components.Sessions.Get)
  component(Components.Radio.GetTracks)
  component(Components.Radio.SaveTracks)

  # Must always return {:ok, frame} — the Hermes notifications/initialized handler
  # (hermes_mcp's base.ex) only pattern-matches {:ok, frame} from init/2 and crashes the session
  # GenServer on anything else. Rejection happens per-request in handle_request/2 below instead.
  @impl true
  def init(_client_info, frame) do
    api_key = Frame.get_req_header(frame, "x-api-key")
    authorization = Frame.get_req_header(frame, "authorization")

    case authenticate(api_key, authorization) do
      {:ok, user} -> {:ok, Frame.assign(frame, :current_user, user)}
      :error -> {:ok, frame}
    end
  end

  # tools/list, prompts/list, resources/list and similar discovery calls stay
  # unauthenticated so claude.ai can display the connector's capabilities before OAuth completes;
  # only calls that actually execute something require an authenticated current_user. The
  # fallback clause for every other method is injected by Hermes.Server's @before_compile hook
  # (def handle_request(%{} = request, frame), do: Handlers.handle(...)) — do not redefine it here.
  @impl true
  def handle_request(%{"method" => method} = request, frame)
      when method in ["tools/call", "prompts/get", "resources/read"] do
    case frame.assigns[:current_user] do
      %User{} -> Handlers.handle(request, __MODULE__, frame)
      _ -> {:error, Error.execution("Unauthorized"), frame}
    end
  end

  @doc false
  @spec authenticate([String.t()] | nil, [String.t()] | nil) :: {:ok, User.t()} | :error
  def authenticate(api_key, authorization) do
    with nil <- by_api_key(api_key) do
      by_bearer_token(authorization)
    end
  end

  defp by_api_key(api_key) do
    api_key = api_key && List.first(api_key)

    case api_key && Token.get_user_by_api_token(api_key) do
      {user, _inserted_at} -> {:ok, user}
      _ -> nil
    end
  end

  # OAuth path for browser-based connectors (e.g. claude.ai) registered via
  # PremiereEcouteWeb.Oauth.RegistrationController; `sub` is the user id set in ResourceOwners.
  defp by_bearer_token(authorization) do
    with [header] <- authorization,
         "Bearer " <> token <- header,
         {:ok, %{sub: sub}} <- AccessToken.authorize(value: token),
         %User{} = user <- Repo.get(User, sub) do
      {:ok, User.preload(user)}
    else
      _ -> :error
    end
  end
end
