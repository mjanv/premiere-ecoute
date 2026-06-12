defmodule PremiereEcouteWeb.Podcasts.AudioController do
  @moduledoc """
  Tracking redirect for episode audio.

  Podcast feeds and the website player both point here rather than directly at object storage:
  the request is recorded as an `EpisodeDownloaded` event (tagged `:feed` or `:web`) and then
  302-redirected to the public storage URL, which serves the bytes (with HTTP range) itself. This
  keeps downloads countable while the heavy traffic stays off the app server.
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Events.EpisodeDownloaded
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Podcasts
  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Show
  alias PremiereEcoute.Podcasts.Storage

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"username" => username, "show_slug" => slug, "guid" => guid} = params) do
    with %Show{id: show_id} <- Podcasts.get_published_show(username, slug),
         %Episode{audio_key: key} = episode when is_binary(key) <- Podcasts.get_published_episode(show_id, guid) do
      track_download(conn, episode, params)
      redirect(conn, external: Storage.public_url(key))
    else
      _ -> send_resp(conn, 404, "Episode not found")
    end
  end

  defp track_download(conn, %Episode{} = episode, params) do
    Store.append(
      %EpisodeDownloaded{
        id: episode.id,
        source: source(params),
        ip: client_ip(conn),
        user_agent: user_agent(conn)
      },
      stream: "podcast_download"
    )
  end

  defp source(%{"source" => "web"}), do: :web
  defp source(_), do: :feed

  defp client_ip(%Plug.Conn{remote_ip: ip}), do: ip |> :inet.ntoa() |> to_string()

  defp user_agent(conn), do: conn |> get_req_header("user-agent") |> List.first()
end
