defmodule PremiereEcoute.Podcasts.Services.Feed do
  @moduledoc """
  Renders a show + its episodes as a podcast RSS 2.0 feed (Apple iTunes namespace included).

  Pure read model: given a `Show`, its feed `Episode`s, and a `urls` map, it returns the feed
  XML string. URLs are injected so the builder stays decoupled from the web router and easily
  testable. The `urls` map provides:

    * `:self` — the public URL of this feed (`<atom:link rel="self">`)
    * `:link` — the show's public web page
    * `:audio` — a 1-arity function `episode -> enclosure_url` (the tracking redirect endpoint)
  """

  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Show

  @rss_attrs %{
    "version" => "2.0",
    "xmlns:itunes" => "http://www.itunes.com/dtds/podcast-1.0.dtd",
    "xmlns:content" => "http://purl.org/rss/1.0/modules/content/",
    "xmlns:atom" => "http://www.w3.org/2005/Atom"
  }

  @doc "Renders the RSS feed XML for a show and its (already filtered) feed episodes."
  @spec render(Show.t(), [Episode.t()], map()) :: String.t()
  def render(%Show{} = show, episodes, urls) do
    channel = {:channel, %{}, channel_elements(show, episodes, urls)}

    {:rss, @rss_attrs, [channel]}
    |> XmlBuilder.document()
    |> XmlBuilder.generate()
  end

  defp channel_elements(show, episodes, urls) do
    [
      {:title, %{}, show.title},
      {:link, %{}, urls[:link]},
      {:language, %{}, show.language},
      {:description, %{}, show.description},
      {"itunes:author", %{}, show.author},
      {"itunes:explicit", %{}, bool(show.explicit)},
      {"atom:link", %{href: urls[:self], rel: "self", type: "application/rss+xml"}, nil}
    ]
    |> maybe(show.cover_url, fn url -> {"itunes:image", %{href: url}, nil} end)
    |> maybe(show.category, fn cat -> {"itunes:category", %{text: cat}, nil} end)
    |> Kernel.++(Enum.map(episodes, &item(&1, show, urls)))
  end

  defp item(%Episode{} = episode, show, urls) do
    {:item, %{},
     [
       {:title, %{}, episode.title},
       {:description, %{}, episode.description},
       {:guid, %{isPermaLink: "false"}, episode.guid},
       {:pubDate, %{}, rfc822(episode.published_at)},
       {:enclosure, %{url: urls[:audio].(episode), length: episode.audio_byte_size, type: "audio/mpeg"}, nil},
       {"itunes:duration", %{}, episode.duration_seconds},
       {"itunes:explicit", %{}, bool(show.explicit)}
     ]}
  end

  defp maybe(elements, nil, _fun), do: elements
  defp maybe(elements, "", _fun), do: elements
  defp maybe(elements, value, fun), do: elements ++ [fun.(value)]

  defp bool(true), do: "true"
  defp bool(_), do: "false"

  # RFC-822 date as required by RSS pubDate, e.g. "Wed, 02 Oct 2002 13:00:00 GMT".
  defp rfc822(nil), do: nil

  defp rfc822(%DateTime{} = dt) do
    dt
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")
  end
end
