defmodule PremiereEcouteWeb.Podcasts.AudioController do
  @moduledoc """
  Streams episode audio through the app.

  Podcast feeds and the website player point here rather than at the object store directly: the
  request is recorded as an `PodcastEpisodeDownloaded` event (tagged `:feed` or `:web`) and the bytes are
  then streamed from storage with HTTP Range support. The object store stays private (no public
  bucket/URL needed) and every download is countable, on a single domain.
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Events.PodcastEpisodeDownloaded
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Podcasts
  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Show
  alias PremiereEcoute.Podcasts.Storage
  alias PremiereEcoute.Telemetry.PodcastMetrics

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"username" => username, "show_slug" => slug, "guid" => guid} = params) do
    with %Show{id: show_id} <- Podcasts.get_published_show(username, slug),
         %Episode{audio_key: key} = episode when is_binary(key) <- Podcasts.get_published_episode(show_id, guid) do
      if head?(conn) do
        # HEAD: clients probe for size/range support — answer with headers only, don't fetch
        # bytes and don't count it as a download.
        head_response(conn, episode)
      else
        track_download(conn, episode, params)
        PodcastMetrics.audio(source(params))
        Storage.send_object(conn, key, "audio/mpeg")
      end
    else
      _ -> send_resp(conn, 404, "Episode not found")
    end
  end

  defp head?(%Plug.Conn{private: %{original_method: "HEAD"}}), do: true
  defp head?(%Plug.Conn{method: "HEAD"}), do: true
  defp head?(_conn), do: false

  defp head_response(conn, %Episode{audio_byte_size: size}) do
    conn
    |> put_resp_header("accept-ranges", "bytes")
    |> put_resp_header("content-type", "audio/mpeg")
    |> maybe_put_length(size)
    |> send_resp(200, "")
  end

  defp maybe_put_length(conn, size) when is_integer(size), do: put_resp_header(conn, "content-length", Integer.to_string(size))
  defp maybe_put_length(conn, _size), do: conn

  defp track_download(conn, %Episode{} = episode, params) do
    Store.append(
      %PodcastEpisodeDownloaded{
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
