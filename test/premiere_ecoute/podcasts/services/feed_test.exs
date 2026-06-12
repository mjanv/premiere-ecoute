defmodule PremiereEcoute.Podcasts.Services.FeedTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Services.Feed
  alias PremiereEcoute.Podcasts.Show

  defp urls do
    %{
      self: "https://premiere-ecoute.fr/podcasts/bob/my-show/feed.xml",
      link: "https://premiere-ecoute.fr/podcasts/bob/my-show",
      audio: fn ep -> "https://premiere-ecoute.fr/podcasts/audio/#{ep.guid}" end
    }
  end

  defp show do
    %Show{
      title: "My Show",
      description: "All about music",
      author: "Bob",
      language: "fr",
      category: "Music",
      explicit: false,
      cover_url: "https://example.com/cover.jpg"
    }
  end

  defp episode do
    %Episode{
      guid: "guid-123",
      title: "Episode One",
      description: "First episode",
      audio_byte_size: 5_242_880,
      duration_seconds: 1830,
      published_at: ~U[2026-06-01 09:00:00Z]
    }
  end

  describe "render/3" do
    test "produces an RSS 2.0 channel with the itunes namespace" do
      xml = Feed.render(show(), [episode()], urls())

      assert xml =~ ~s(<rss)
      assert xml =~ ~s(version="2.0")
      assert xml =~ "http://www.itunes.com/dtds/podcast-1.0.dtd"
      assert xml =~ "<channel>"
    end

    test "includes channel-level show metadata" do
      xml = Feed.render(show(), [episode()], urls())

      assert xml =~ "<title>My Show</title>"
      assert xml =~ "<language>fr</language>"
      assert xml =~ "<itunes:author>Bob</itunes:author>"
      assert xml =~ ~s(<itunes:image href="https://example.com/cover.jpg")
      assert xml =~ ~s(<itunes:category text="Music")
      assert xml =~ ~s(rel="self")
    end

    test "renders an item with a stable guid and an audio enclosure" do
      xml = Feed.render(show(), [episode()], urls())

      assert xml =~ "<item>"
      assert xml =~ "<title>Episode One</title>"
      assert xml =~ ~s(isPermaLink="false")
      assert xml =~ "guid-123"
      assert xml =~ ~s(type="audio/mpeg")
      assert xml =~ ~s(url="https://premiere-ecoute.fr/podcasts/audio/guid-123")
      assert xml =~ ~s(length="5242880")
      assert xml =~ "<itunes:duration>1830</itunes:duration>"
    end

    test "formats pubDate as an RFC-822 date" do
      xml = Feed.render(show(), [episode()], urls())

      assert xml =~ "<pubDate>Mon, 01 Jun 2026 09:00:00 GMT</pubDate>"
    end

    test "declares an episodic show type" do
      xml = Feed.render(show(), [episode()], urls())
      assert xml =~ "<itunes:type>episodic</itunes:type>"
    end

    test "emits the owner email when the user is loaded (Apple verification)" do
      with_owner = %{show() | user: %{email: "bob@example.com"}}
      xml = Feed.render(with_owner, [episode()], urls())

      assert xml =~ "<itunes:owner>"
      assert xml =~ "<itunes:email>bob@example.com</itunes:email>"
    end

    test "omits the owner block when the user is not loaded" do
      xml = Feed.render(show(), [episode()], urls())
      refute xml =~ "itunes:owner"
    end

    test "omits optional cover/category when absent" do
      bare = %{show() | cover_url: nil, category: nil}
      xml = Feed.render(bare, [], urls())

      refute xml =~ "itunes:image"
      refute xml =~ "itunes:category"
      refute xml =~ "<item>"
    end
  end
end
