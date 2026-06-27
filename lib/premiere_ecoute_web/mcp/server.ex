defmodule PremiereEcouteWeb.Mcp.Server do
  @moduledoc false

  alias Boruta.Oauth.Authorization.AccessToken
  alias Hermes.Server.Frame
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

  @impl true
  def init(_client_info, frame) do
    api_key = Frame.get_req_header(frame, "x-api-key")
    authorization = Frame.get_req_header(frame, "authorization")

    case authenticate(api_key, authorization) do
      {:ok, user} -> {:ok, Frame.assign(frame, :current_user, user)}
      :error -> {:stop, :unauthorized}
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

  # AIDEV-NOTE: OAuth path for browser-based connectors (e.g. claude.ai) registered via
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
