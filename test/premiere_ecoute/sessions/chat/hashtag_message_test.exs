defmodule PremiereEcoute.Sessions.Chat.HashtagMessageTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Sessions.Chat.HashtagMessage
  alias PremiereEcouteCore.Cache

  setup do
    Cache.clear(:hashtags)
    on_exit(fn -> Cache.clear(:hashtags) end)
  end

  describe "parse/1" do
    test "extracts the hashtag from a message and strips it from the remaining text" do
      assert HashtagMessage.parse("#hype this album is fire") == {:ok, {"#hype", "this album is fire"}}
    end

    test "extracts only the first hashtag when multiple are present, leaving the rest in the text" do
      assert HashtagMessage.parse("#hype #newalbum this is fire") ==
               {:ok, {"#hype", "#newalbum this is fire"}}
    end

    test "finds a hashtag anywhere in the message" do
      assert HashtagMessage.parse("this is fire #hype") == {:ok, {"#hype", "this is fire"}}
    end

    test "returns :error when no hashtag is present" do
      assert HashtagMessage.parse("this album is fire") == :error
    end

    test "returns :error for a bare # with no word characters" do
      assert HashtagMessage.parse("just a # symbol") == :error
    end
  end

  describe "put/3 and list/1" do
    test "caches a message and lists it back for the broadcaster" do
      HashtagMessage.put("1234", "#hype", "this is fire")

      assert [%{hashtag: "#hype", message: "this is fire"}] = HashtagMessage.list("1234")
    end

    test "keeps insertion order" do
      HashtagMessage.put("1234", "#hype", "first")
      HashtagMessage.put("1234", "#newalbum", "second")

      assert [%{message: "first"}, %{message: "second"}] = HashtagMessage.list("1234")
    end

    test "isolates messages per broadcaster" do
      HashtagMessage.put("1234", "#hype", "for broadcaster 1234")
      HashtagMessage.put("5678", "#hype", "for broadcaster 5678")

      assert [%{message: "for broadcaster 1234"}] = HashtagMessage.list("1234")
      assert [%{message: "for broadcaster 5678"}] = HashtagMessage.list("5678")
    end

    test "broadcasts the new entry to the broadcaster's hashtag topic" do
      PremiereEcoute.PubSub.subscribe("hashtags:1234")

      HashtagMessage.put("1234", "#hype", "this is fire")

      assert_receive {:hashtag_message, %{hashtag: "#hype", message: "this is fire"}}
    end
  end
end
