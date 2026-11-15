defmodule PremiereEcouteWeb.Wrapped.PixelStoriesTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PremiereEcouteWeb.Wrapped.PixelStories

  defp album(n, attrs \\ %{}),
    do:
      Map.merge(
        %{"name" => "Album #{n}", "artist" => "Artist #{n}", "cover_url" => "https://i.scdn.co/image/#{n}", "score" => 9.5},
        attrs
      )

  defp card(type, data), do: %{"type" => type, "appearance" => %{"colors" => ["#112233"]}, "preview" => nil, "data" => data}

  defp recap, do: card("recap", %{"top" => Enum.map(1..3, &album/1), "albums" => 12, "minutes" => 540})

  defp stories(cards, assigns \\ []) do
    assigns = Keyword.merge([year: 2026, cards: cards], assigns)

    render_component(&PixelStories.stories/1, assigns) |> LazyHTML.from_fragment()
  end

  defp count(html, selector), do: html |> LazyHTML.query(selector) |> Enum.count()

  defp text(html, selector),
    do: html |> LazyHTML.query(selector) |> LazyHTML.text() |> String.replace(~r/\s+/, " ") |> String.trim()

  defp data(html, name), do: html |> LazyHTML.query("#wrapped-player") |> LazyHTML.attribute("data-#{name}") |> hd()

  describe "stories/1" do
    test "renders one canvas driven by the pixel hook" do
      html = stories([recap()])

      assert count(html, "#wrapped-player[phx-hook=WrappedPlayerPixel][data-render=pixel][phx-update=ignore]") == 1
      assert count(html, "canvas[data-screen][aria-hidden=true]") == 1
      assert data(html, "year") == "2026"
    end

    test "plays with the render it is given" do
      html = stories([recap()], render: %{id: :pixel2, hook: "WrappedPlayerPixelTwo"})

      assert count(html, "#wrapped-player[phx-hook=WrappedPlayerPixelTwo][data-render=pixel2]") == 1
    end

    test "sends the cards as data: their type and what they show" do
      html = stories([card("year_in_music", %{"albums" => 12, "minutes" => 540}), recap()])

      assert [%{"type" => "year_in_music", "data" => %{"albums" => 12, "minutes" => 540}} = first, %{"type" => "recap"}] =
               html |> data("cards") |> Jason.decode!()

      assert Map.keys(first) == ["data", "type"]
    end

    test "serves every cover through the image proxy, however deep" do
      cards = [
        card("top_album", %{"album" => album(1)}),
        card("cover_wall", %{"covers" => [album(2), album(3, %{"cover_url" => nil})]})
      ]

      assert [%{"data" => %{"album" => top}}, %{"data" => %{"covers" => [second, third]}}] =
               stories(cards) |> data("cards") |> Jason.decode!()

      assert top["cover_url"] == "/img?url=https%3A%2F%2Fi.scdn.co%2Fimage%2F1"
      assert second["cover_url"] == "/img?url=https%3A%2F%2Fi.scdn.co%2Fimage%2F2"
      assert third["cover_url"] == nil
      assert top["name"] == "Album 1"
    end

    test "writes the sessions of each room in words" do
      rooms = [%{"name" => "ana", "sessions" => 3}, %{"name" => "ben", "sessions" => 1}]

      assert [%{"data" => %{"rooms" => [%{"label" => "3 sessions"}, %{"label" => "1 session"}]}}] =
               stories([card("your_rooms", %{"rooms" => rooms})]) |> data("cards") |> Jason.decode!()
    end

    test "sends the labels the hook draws" do
      labels = stories([recap()]) |> data("labels") |> Jason.decode!()

      assert %{"album" => "album", "albums" => "albums", "minute" => "minute", "minutes" => "minutes"} = labels
      assert %{"you" => "You", "chat" => "The chat", "album_of_year" => "Your album of the year"} = labels
      assert length(labels["months"]) == 12
      assert hd(labels["months"]) == "January"
      assert [_, _] = labels["intro"]
    end

    test "sends the tagline of the posters and the caption of each half of the chat card" do
      labels = stories([recap()]) |> data("labels") |> Jason.decode!()

      assert labels["tagline"] == "Your year in music"
      assert labels["own_way"] == "Where you went your own way"
      assert labels["same_thing"] == "Where you heard the same thing"
    end

    test "sends the name of the owner of a shared Wrapped" do
      html = stories([recap()], owner: "maxime")

      assert data(html, "owner") == "maxime"
    end

    test "gives the owner a share button and a visitor a link to their own Wrapped" do
      own = stories([recap()], share_url: "https://premiere-ecoute.fr/wrapped/2026/s/token")
      shared = stories([recap()], owner: "maxime")

      assert data(own, "share-url") == "https://premiere-ecoute.fr/wrapped/2026/s/token"
      assert count(own, "[data-actions][hidden] [data-share]") == 1
      assert count(own, "[data-actions] [data-replay]") == 1
      assert count(shared, "[data-share]") == 0
      assert text(shared, "[data-actions] a[href='/wrapped/2026']") == "See yours"
    end

    test "shows the start button and keeps the playback controls hidden until it starts" do
      html = stories([recap()], exit_to: "/home")

      assert text(html, "[data-begin]") == "Start"
      assert count(html, "[data-pause][hidden]") == 1
      assert count(html, "[data-mute][hidden]") == 1
      assert count(html, "[data-prev][hidden]") == 1
      assert count(html, "[data-next][hidden]") == 1
      assert count(html, "header a[href='/home']") == 1
    end

    test "says in words what the canvas shows" do
      track = %{"name" => "Song", "album" => "Album 1", "artist" => "Artist 1", "cover_url" => nil, "score" => 10.0}

      cards = [
        card("year_in_music", %{"albums" => 12, "minutes" => 540}),
        card("cover_wall", %{"covers" => [album(1), album(2)]}),
        card("your_months", %{"months" => [0, 1, 0, 0, 4, 0, 0, 0, 0, 0, 2, 0], "busiest" => 5}),
        card("your_rooms", %{"rooms" => [%{"name" => "ana", "sessions" => 3}]}),
        card("first_vote", %{"album" => album(1), "date" => "2026-03-12"}),
        card("top_album", %{"album" => album(1)}),
        card("next_albums", %{"albums" => [album(2), album(3)]}),
        card("top_track", %{"track" => track}),
        card("next_tracks", %{"tracks" => [track]}),
        card("top_single", %{"single" => album(4, %{"name" => "Single", "artist" => nil})}),
        card("you_and_chat", %{
          "furthest" => Map.merge(album(1), %{"you" => 9.0, "chat" => 5}),
          "closest" => Map.merge(album(2), %{"you" => 7, "chat" => 7.2})
        }),
        recap(),
        %{"type" => "retired_card"}
      ]

      words = stories(cards) |> text("ol.sr-only")

      assert words =~ "12 albums, 540 minutes"
      assert words =~ "Every cover, in order: Album 1 — Artist 1, Album 2 — Artist 2"
      assert words =~ "Your busiest month: May"
      assert words =~ "Where you listened: ana (3 sessions)"
      assert words =~ "It started with: Album 1 — Artist 1, 2026-03-12"
      assert words =~ "Your album of the year: Album 1 — Artist 1, 9.5"
      assert words =~ "Right behind: Album 2 — Artist 2, 9.5, Album 3 — Artist 3, 9.5"
      assert words =~ "Your track of the year: Song — Artist 1, 10.0"
      assert words =~ "More tracks you loved: Song — Artist 1, 10.0"
      assert words =~ "Your single of the year: Single, 9.5"
      assert words =~ "Where you went your own way: Album 1 — Artist 1, You 9.0, The chat 5.0"
      assert words =~ "Where you heard the same thing: Album 2 — Artist 2, You 7.0, The chat 7.2"
    end
  end
end
