defmodule PremiereEcouteWeb.Mcp.Server do
  @moduledoc false

  alias Hermes.Server.Frame
  alias PremiereEcoute.Accounts.User.Token
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

    case api_key && Token.get_user_by_api_token(api_key) do
      {user, _inserted_at} -> {:ok, Frame.assign(frame, :current_user, user)}
      _ -> {:stop, :unauthorized}
    end
  end
end
