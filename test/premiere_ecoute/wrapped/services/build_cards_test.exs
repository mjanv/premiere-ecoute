defmodule PremiereEcoute.Wrapped.Services.BuildCardsTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.Wrapped.ListenFixtures
  import PremiereEcoute.Wrapped.WrappedFixtures

  alias PremiereEcoute.Wrapped.Appearance
  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Services.BuildCards

  @types ~w(year_in_music cover_wall your_rooms your_months first_vote top_album next_albums top_track next_tracks top_single you_and_chat recap)a

  # Five scored albums over five months and two streamers, a rated track on each, and a scored single
  defp full_year do
    albums =
      for n <- 1..5, do: album_listen(n, %{score: n + 4.0, chat_score: 7.0, streamers: [Enum.at(["ana", "ben"], rem(n, 2))]})

    tracks = for n <- 1..5, do: track_listen(n, "Song #{n}", %{score: n + 5.0})

    albums ++ tracks ++ [single_listen(6, %{score: 9.0})]
  end

  # Answers every cover download with a plain image of the given colour, and tells the test which path was fetched
  defp stub_covers(colors) do
    test = self()

    Req.Test.stub(Appearance, fn conn ->
      send(test, {:fetched, conn.request_path})

      case colors[conn.request_path] do
        nil -> Plug.Conn.send_resp(conn, 404, "")
        {r, g, b} -> conn |> Plug.Conn.put_resp_content_type("image/png") |> Plug.Conn.send_resp(200, png({r, g, b}))
      end
    end)
  end

  defp png({r, g, b}),
    do: StbImage.new(:binary.copy(<<r, g, b>>, 16), {4, 4, 3}) |> StbImage.to_binary(:png)

  describe "cards/1" do
    setup do
      stub_covers()
    end

    test "builds every card, in play order" do
      cards = BuildCards.cards(full_year())

      assert Enum.all?(cards, &match?(%Card{}, &1))
      assert Enum.map(cards, & &1.type) == @types
    end

    test "leaves out the cards with too little to show" do
      listens = for n <- 1..3, do: album_listen(3, %{name: "Album #{n}", score: 8.0})

      assert listens |> BuildCards.cards() |> Enum.map(& &1.type) == ~w(year_in_music first_vote top_album next_albums recap)a
    end

    test "builds nothing below 3 albums, whatever the singles and the tracks" do
      listens = [
        album_listen(1, %{score: 9.0}),
        album_listen(2, %{score: 9.0}),
        single_listen(3, %{score: 9.0}),
        track_listen(1, "Song", %{score: 9.0})
      ]

      assert BuildCards.cards(listens) == []
      assert BuildCards.cards([]) == []
      assert [_ | _] = BuildCards.cards([album_listen(3, %{score: 9.0}) | listens])
    end

    # Pins current behaviour: unscored albums count towards the minimum, so this viewer gets a Wrapped without recap card
    test "builds a Wrapped without recap card from albums without score" do
      types = 1..3 |> Enum.map(&album_listen/1) |> BuildCards.cards() |> Enum.map(& &1.type)

      assert :year_in_music in types
      refute :top_album in types
      refute :recap in types
    end
  end

  describe "cards/1, colours" do
    test "gives each card the colours of its own cover" do
      stub_covers(%{"/image/1" => {200, 20, 20}, "/image/5" => {20, 20, 200}})

      cards = BuildCards.cards(full_year())

      assert %Card{appearance: %{cover_url: "https://i.scdn.co/image/1", colors: ["#c81414"]}} =
               Enum.find(cards, &(&1.type == :first_vote))

      assert %Card{appearance: %{cover_url: "https://i.scdn.co/image/5", colors: ["#1414c8"]}} =
               Enum.find(cards, &(&1.type == :top_album))
    end

    test "downloads a cover once, however many cards use it" do
      stub_covers(%{})
      listens = for n <- 1..4, do: album_listen(n, %{cover_url: "https://i.scdn.co/image/same", score: 8.0, chat_score: 7.0})

      cards = BuildCards.cards(listens)

      assert length(cards) > 3
      assert_received {:fetched, "/image/same"}
      refute_received {:fetched, _}
    end

    test "leaves a card without colour when its cover cannot be read or is missing" do
      stub_covers(%{})

      listens =
        for n <- 1..3,
            do: album_listen(n, %{cover_url: if(n == 3, do: nil, else: "https://i.scdn.co/image/#{n}"), score: n * 1.0})

      cards = BuildCards.cards(listens)

      assert Enum.all?(cards, &(&1.appearance.colors == []))
      refute_received {:fetched, nil}
    end
  end

  describe "demo_cards/0" do
    setup do
      stub_covers()
    end

    test "builds stored-like cards from the albums of the discography" do
      for n <- 1..4, do: album_record(n)

      cards = BuildCards.demo_cards()

      assert [%{"type" => "year_in_music", "data" => %{"albums" => 4}, "appearance" => %{"colors" => []}} | _] = cards
      assert %{"preview" => %{"artist" => "Sample Artist", "name" => _}} = Enum.find(cards, &(&1["type"] == "top_single"))
    end

    test "builds nothing from an empty discography" do
      assert BuildCards.demo_cards() == []
    end
  end
end
