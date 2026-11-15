defmodule PremiereEcoute.Wrapped.Cards.YouAndChatTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Cards.YouAndChat

  describe "compute/1" do
    test "finds the albums the furthest from and the closest to the chat" do
      listens = [
        album_listen(1, %{score: 9.0, chat_score: 5.0}),
        album_listen(2, %{score: 7.0, chat_score: 7.2}),
        album_listen(3, %{score: 4.0, chat_score: 6.0})
      ]

      assert %Card{type: :you_and_chat, data: data, appearance: appearance, preview: preview} = YouAndChat.compute(listens)
      assert data.furthest == %{name: "Album 1", artist: "Artist 1", cover_url: "https://i.scdn.co/image/1", you: 9.0, chat: 5.0}
      assert data.closest == %{name: "Album 2", artist: "Artist 2", cover_url: "https://i.scdn.co/image/2", you: 7.0, chat: 7.2}
      assert appearance.cover_url == "https://i.scdn.co/image/1"
      assert preview == %Card.Track{artist: "Artist 1", name: "Intro 1"}
    end

    test "counts a score below the chat as far as a score above it" do
      listens = [album_listen(1, %{score: 2.0, chat_score: 8.0}), album_listen(2, %{score: 9.0, chat_score: 5.0})]

      assert %Card{data: %{furthest: %{name: "Album 1"}, closest: %{name: "Album 2"}}} = YouAndChat.compute(listens)
    end

    test "leaves out albums missing one of the two scores, singles and tracks" do
      listens = [
        album_listen(1, %{score: 9.0, chat_score: 5.0}),
        album_listen(2, %{score: 10.0}),
        album_listen(3, %{chat_score: 1.0}),
        single_listen(4, %{score: 0.0, chat_score: 10.0}),
        album_listen(5, %{score: 6.0, chat_score: 5.0})
      ]

      assert %Card{data: %{furthest: %{name: "Album 1"}, closest: %{name: "Album 5"}}} = YouAndChat.compute(listens)
    end

    # Pins current behaviour: with equal gaps the first album is the closest and the last the furthest
    test "keeps the order of the albums on equal gaps" do
      listens = for n <- 1..3, do: album_listen(n, %{score: 8.0, chat_score: 7.0})

      assert %Card{data: %{closest: %{name: "Album 1"}, furthest: %{name: "Album 3"}}} = YouAndChat.compute(listens)
    end

    # Pins current behaviour: a viewer who always agrees with the chat still gets a "furthest" album, with no gap
    test "shows a furthest album without gap when every score matches the chat" do
      listens = for n <- 1..2, do: album_listen(n, %{score: 8.0, chat_score: 8.0})

      assert %Card{data: %{furthest: %{you: 8.0, chat: 8.0}}} = YouAndChat.compute(listens)
    end

    test "skips with fewer than 2 comparable albums" do
      assert YouAndChat.compute([album_listen(1, %{score: 9.0, chat_score: 5.0}), album_listen(2, %{score: 9.0})]) == :skip
      assert YouAndChat.compute([]) == :skip
    end
  end
end
