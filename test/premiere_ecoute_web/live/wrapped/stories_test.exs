defmodule PremiereEcouteWeb.Wrapped.StoriesTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PremiereEcouteWeb.Wrapped.Stories

  defp album(n, attrs \\ %{}),
    do:
      Map.merge(
        %{"name" => "Album #{n}", "artist" => "Artist #{n}", "cover_url" => "https://i.scdn.co/image/#{n}", "score" => 9.5},
        attrs
      )

  defp card(type, data, appearance \\ %{"colors" => []}),
    do: %{"type" => type, "appearance" => appearance, "preview" => nil, "data" => data}

  defp recap, do: card("recap", %{"top" => Enum.map(1..3, &album/1), "albums" => 12, "minutes" => 540})

  defp stories(cards, assigns \\ []) do
    assigns = Keyword.merge([year: 2026, cards: cards], assigns)

    render_component(&Stories.stories/1, assigns) |> LazyHTML.from_fragment()
  end

  defp count(html, selector), do: html |> LazyHTML.query(selector) |> Enum.count()

  defp text(html, selector),
    do: html |> LazyHTML.query(selector) |> LazyHTML.text() |> String.replace(~r/\s+/, " ") |> String.trim()

  describe "stories/1" do
    test "renders the start screen, then one section and one progress bar per card" do
      html = stories([card("year_in_music", %{"albums" => 12, "minutes" => 540}), recap()])

      assert count(html, "#wrapped-player[phx-hook=WrappedPlayer] [data-start] [data-begin]") == 1
      assert count(html, "[data-card]") == 2
      assert count(html, "[data-progress]") == 2
      assert count(html, "[data-card][data-type=year_in_music].wrapped-year-in-music") == 1
    end

    test "plays with the classic render unless another one is given" do
      default = stories([recap()])
      other = stories([recap()], render: %{id: :shader, hook: "WrappedPlayerShader"})

      assert count(default, "#wrapped-player[phx-hook=WrappedPlayer][data-render=classic]") == 1
      assert count(other, "#wrapped-player[phx-hook=WrappedPlayerShader][data-render=shader]") == 1
    end

    test "introduces the Wrapped to its owner, and to a visitor by the name of its owner" do
      own = stories([recap()])
      shared = stories([recap()], owner: "maxime")

      assert count(own, "[data-start] .wrapped-lead") == 2
      assert text(own, "[data-start]") =~ "what you listened to"
      assert text(shared, "[data-start] .wrapped-label") == "maxime"
      assert text(shared, "[data-start]") =~ "what they listened to"
    end

    test "passes the colours of each card to the player" do
      html = stories([card("first_vote", %{"album" => album(1), "date" => "2026-03-12"}, %{"colors" => ["#112233", "#445566"]})])

      assert count(html, ~s([data-card][data-colors='["#112233","#445566"]'])) == 1
    end

    test "gives a card without appearance no colour" do
      html = stories([%{"type" => "first_vote", "data" => %{"album" => album(1), "date" => "2026-03-12"}}])

      assert count(html, "[data-card][data-colors='[]']") == 1
    end

    test "renders an empty section for a card it does not know" do
      html = stories([%{"type" => "retired_card"}, recap()])

      assert count(html, "[data-card]") == 2
      assert text(html, "[data-card].wrapped-retired-card") == ""
    end
  end

  describe "year/1" do
    test "splits the year on two lines" do
      assert render_component(&Stories.year/1, year: 2026) =~ ~r/>20<.*>26</s
      assert render_component(&Stories.year/1, year: 2105) =~ ~r/>21<.*>05</s
    end
  end

  describe "year_in_music card" do
    test "shows the albums and the minutes" do
      html = stories([card("year_in_music", %{"albums" => 1, "minutes" => 540})])

      assert text(html, ".wrapped-year-in-music") == "1 album 540 minutes"
      assert count(html, ".wrapped-figure-outline") == 1
    end

    test "leaves the minutes out when there are none" do
      html = stories([card("year_in_music", %{"albums" => 3, "minutes" => 0})])

      assert text(html, ".wrapped-year-in-music") == "3 albums"
    end
  end

  describe "cover_wall card" do
    defp wall(count), do: stories([card("cover_wall", %{"covers" => Enum.map(1..count//1, &album/1)})])

    test "lays the covers on a grid that grows with their number" do
      assert count(wall(4), ".wrapped-wall[style='--cols: 2']") == 1
      assert count(wall(7), ".wrapped-wall[style='--cols: 3']") == 1
      assert count(wall(19), ".wrapped-wall[style='--cols: 4']") == 1
      assert count(wall(37), ".wrapped-wall[style='--cols: 5']") == 1
    end

    test "completes the last row with empty tiles" do
      assert {count(wall(4), ".wrapped-wall img"), count(wall(4), ".wrapped-wall-empty")} == {4, 0}
      assert {count(wall(5), ".wrapped-wall img"), count(wall(5), ".wrapped-wall-empty")} == {5, 1}
      assert {count(wall(7), ".wrapped-wall img"), count(wall(7), ".wrapped-wall-empty")} == {7, 2}
    end

    test "shows 60 covers at most" do
      assert count(wall(70), ".wrapped-wall img") == 60
    end

    test "describes each cover" do
      assert count(wall(4), ~s(.wrapped-wall img[alt="Album 1 — Artist 1"])) == 1
    end
  end

  describe "your_months card" do
    test "names the busiest month and draws one column per month" do
      html = stories([card("your_months", %{"months" => [0, 1, 0, 0, 4, 0, 0, 0, 0, 0, 2, 0], "busiest" => 5})])

      assert text(html, ".wrapped-shout") == "May"
      assert count(html, ".wrapped-months li") == 12
      assert text(html, ".wrapped-months .is-busiest") == "4 M"
      assert count(html, ".wrapped-months .is-busiest i[style='height: 100%']") == 1
      assert count(html, ".wrapped-months i[style='height: 50%']") == 1
      assert count(html, ".wrapped-months i[style='height: 2%']") == 9
      assert count(html, ".wrapped-months b") == 3
    end
  end

  describe "your_rooms card" do
    test "lists the streamers with their sessions" do
      html =
        stories([card("your_rooms", %{"rooms" => [%{"name" => "ana", "sessions" => 3}, %{"name" => "ben", "sessions" => 1}]})])

      assert text(html, ".wrapped-rooms li:first-child") == "ana 3 sessions"
      assert text(html, ".wrapped-rooms li:last-child") == "ben 1 session"
    end
  end

  describe "first_vote card" do
    test "shows the album and the day of the first vote" do
      html = stories([card("first_vote", %{"album" => album(1), "date" => "2026-03-12"})])

      assert text(html, ".wrapped-first-vote .wrapped-name") == "Album 1 Artist 1"
      assert text(html, ".wrapped-date") == "12 March"
      assert count(html, ".wrapped-first-vote .wrapped-hero-score") == 0
    end
  end

  describe "top cards" do
    test "show the top album with its score and its rank" do
      html = stories([card("top_album", %{"album" => album(1, %{"score" => 9})})])

      assert text(html, ".wrapped-top-album .wrapped-hero-score") == "9.0"
      assert text(html, ".wrapped-top-album .wrapped-hero-rank") == "1"
      assert text(html, ".wrapped-top-album .wrapped-name") == "Album 1 Artist 1"
    end

    test "show the top track with the cover of its album" do
      track = %{
        "name" => "Song",
        "album" => "Album 1",
        "artist" => "Artist 1",
        "cover_url" => "https://i.scdn.co/image/1",
        "score" => 10.0
      }

      html = stories([card("top_track", %{"track" => track})])

      assert text(html, ".wrapped-top-track .wrapped-name") == "Song Artist 1"
      assert text(html, ".wrapped-top-track .wrapped-hero-score") == "10.0"
      assert count(html, ".wrapped-top-track .wrapped-hero img") == 1
    end

    test "show the top single without rank" do
      html = stories([card("top_single", %{"single" => album(1, %{"name" => "Single"})})])

      assert text(html, ".wrapped-top-single .wrapped-name") == "Single Artist 1"
      assert count(html, ".wrapped-top-single .wrapped-hero-rank") == 0
    end
  end

  describe "next cards" do
    test "rank the next albums from 2" do
      html = stories([card("next_albums", %{"albums" => [album(2, %{"score" => 9.0}), album(3, %{"score" => 8.5})]})])

      assert text(html, ".wrapped-next-albums li:first-child") == "2 Album 2 Artist 2 9.0"
      assert text(html, ".wrapped-next-albums li:last-child") == "3 Album 3 Artist 3 8.5"
    end

    test "rank the next tracks from 2" do
      track = %{"name" => "Song", "album" => "Album 1", "artist" => "Artist 1", "cover_url" => nil, "score" => 9.0}
      html = stories([card("next_tracks", %{"tracks" => [track, track, track]})])

      assert count(html, ".wrapped-next-tracks li") == 3
      assert text(html, ".wrapped-next-tracks li:last-child") == "4 Song Artist 1 9.0"
    end
  end

  describe "you_and_chat card" do
    test "faces the viewer's score and the chat's, for the furthest and the closest albums" do
      data = %{
        "furthest" => album(1) |> Map.merge(%{"you" => 9.0, "chat" => 5}),
        "closest" => album(2) |> Map.merge(%{"you" => 7.0, "chat" => 7.2})
      }

      html = stories([card("you_and_chat", data)])

      assert count(html, ".wrapped-versus") == 2
      assert text(html, ".wrapped-versus:first-of-type") =~ "Album 1 Artist 1 9.0 You ≠ 5.0 The chat"
      assert text(html, ".wrapped-versus:last-of-type") =~ "Album 2 Artist 2 7.0 You = 7.2 The chat"
    end
  end

  describe "recap card" do
    test "lets its owner share and replay" do
      html = stories([recap()], share_url: "https://premiere-ecoute.fr/wrapped/2026/s/token")

      assert count(html, "#wrapped-player[data-share-url='https://premiere-ecoute.fr/wrapped/2026/s/token']") == 1
      assert count(html, ".wrapped-recap [data-share]") == 1
      assert count(html, ".wrapped-recap [data-replay]") == 1
      assert count(html, ".wrapped-recap a[href='/wrapped/2026']") == 0
    end

    test "invites a visitor to see their own" do
      html = stories([recap()], owner: "maxime")

      assert count(html, ".wrapped-recap [data-share]") == 0
      assert text(html, ".wrapped-recap a[href='/wrapped/2026']") == "See yours"
      assert text(html, ".wrapped-recap .wrapped-label") == "maxime"
    end

    test "sums up the top albums and the figures" do
      html = stories([recap()])

      assert count(html, ".wrapped-fan img") == 3
      assert text(html, ".wrapped-top li:first-child") == "Album 1 Artist 1"
      assert text(html, ".wrapped-stats") == "12 albums 540 minutes"
    end

    test "leaves the minutes out when there are none" do
      html = stories([card("recap", %{"top" => Enum.map(1..3, &album/1), "albums" => 3, "minutes" => 0})])

      assert text(html, ".wrapped-stats") == "3 albums"
    end
  end
end
