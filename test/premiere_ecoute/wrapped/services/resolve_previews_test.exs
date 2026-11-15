defmodule PremiereEcoute.Wrapped.Services.ResolvePreviewsTest do
  # Not async: sound is toggled in the application environment
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Apis.MusicProvider.DeezerApi.Mock, as: DeezerApi
  alias PremiereEcoute.Wrapped
  alias PremiereEcoute.Wrapped.Appearance
  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Services.ResolvePreviews

  defp card(name), do: %{"type" => "top_album", "preview" => %{"artist" => "Artist", "name" => name}}

  defp sound(enabled?) do
    config = Application.get_env(:premiere_ecoute, Wrapped, [])
    Application.put_env(:premiere_ecoute, Wrapped, Keyword.put(config, :sound, enabled?))
    on_exit(fn -> Application.put_env(:premiere_ecoute, Wrapped, config) end)
  end

  # Tells the test about every lookup: an unexpected call would otherwise be rescued and go unnoticed
  defp deezer(answer) do
    test = self()

    stub(DeezerApi, :get_track_preview, fn artist, name ->
      send(test, {:lookup, artist, name})
      answer.(name)
    end)
  end

  describe "previews/1, sound disabled" do
    test "resolves nothing and looks nothing up" do
      sound(false)
      deezer(fn _ -> {:ok, "https://preview"} end)

      assert ResolvePreviews.previews([card("One"), %{"preview" => nil}]) == [nil, nil]
      refute_received {:lookup, _, _}
    end
  end

  describe "previews/1, sound enabled" do
    setup do
      sound(true)
    end

    test "resolves one URL per card, in card order" do
      deezer(fn name -> {:ok, "https://preview/#{name}"} end)

      assert ResolvePreviews.previews([card("One"), card("Two"), card("Three")]) ==
               ["https://preview/One", "https://preview/Two", "https://preview/Three"]

      assert_received {:lookup, "Artist", "One"}
    end

    test "looks nothing up for a card without track" do
      deezer(fn _ -> {:ok, "https://preview"} end)

      cards = [%{"type" => "cover_wall", "preview" => nil}, %{"type" => "cover_wall"}, card("One")]

      assert ResolvePreviews.previews(cards) == [nil, nil, "https://preview"]
      assert_received {:lookup, "Artist", "One"}
      refute_received {:lookup, _, _}
    end

    # Cards are read as stored (string keys): a %Card{} struct fresh from a card module has no preview here
    test "reads stored cards only" do
      deezer(fn _ -> {:ok, "https://preview"} end)
      card = %Card{type: :top_album, appearance: %Appearance{}, preview: %Card.Track{artist: "Artist", name: "One"}}

      assert ResolvePreviews.previews([card]) == [nil]
      assert ResolvePreviews.previews([card |> Jason.encode!() |> Jason.decode!()]) == ["https://preview"]
    end

    test "gives no URL when Deezer has no preview or fails" do
      deezer(fn
        "Unknown" -> {:ok, nil}
        "Broken" -> {:error, :quota}
        _ -> {:ok, "https://preview"}
      end)

      assert ResolvePreviews.previews([card("Unknown"), card("Broken"), card("One")]) == [nil, nil, "https://preview"]
    end

    test "survives a lookup that raises or exits" do
      deezer(fn
        "Raise" -> raise "boom"
        "Exit" -> exit(:boom)
        _ -> {:ok, "https://preview"}
      end)

      assert ResolvePreviews.previews([card("Raise"), card("One"), card("Exit")]) == [nil, "https://preview", nil]
    end

    test "resolves nothing without card" do
      assert ResolvePreviews.previews([]) == []
    end
  end
end
