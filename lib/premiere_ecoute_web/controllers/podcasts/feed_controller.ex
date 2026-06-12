defmodule PremiereEcouteWeb.Podcasts.FeedController do
  @moduledoc """
  Serves a show's public podcast RSS feed.

  The feed is unauthenticated and content-negotiation-free (podcast apps send arbitrary Accept
  headers), so it bypasses the browser pipeline's `accepts ["html"]` and writes the XML directly.
  Enclosure URLs point at the tracking redirect (`AudioController`) so downloads are measured.
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Podcasts

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"username" => username, "show_slug" => slug}) do
    case Podcasts.get_published_show(username, slug) do
      nil ->
        send_resp(conn, 404, "Feed not found")

      show ->
        urls = %{
          self: url(~p"/podcasts/#{username}/#{slug}/feed.xml"),
          link: url(~p"/podcasts/#{username}/#{slug}"),
          audio: fn episode -> url(~p"/podcasts/#{username}/#{slug}/episodes/#{episode.guid}/audio") end
        }

        conn
        |> put_resp_content_type("application/rss+xml")
        |> send_resp(200, Podcasts.render_feed(show, urls))
    end
  end
end
