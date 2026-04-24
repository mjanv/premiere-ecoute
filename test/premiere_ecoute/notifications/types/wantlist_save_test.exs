defmodule PremiereEcoute.Notifications.Types.WantlistSaveTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Notifications.Types.WantlistSave

  @struct %WantlistSave{track_name: "Around the World", artist_name: "Daft Punk"}

  describe "type/0" do
    test "returns the registered type string" do
      assert WantlistSave.type() == "wantlist_save"
    end
  end

  describe "channels/0" do
    test "declares pubsub as the only channel" do
      assert WantlistSave.channels() == [:pubsub]
    end
  end

  describe "render/1" do
    test "uses the track name as title" do
      rendered = WantlistSave.render(@struct)
      assert rendered.title == "Around the World"
    end

    test "uses the artist name as body" do
      rendered = WantlistSave.render(@struct)
      assert rendered.body == "Daft Punk"
    end

    test "points to the wantlist page" do
      rendered = WantlistSave.render(@struct)
      assert rendered.path == "/wantlist"
    end

    test "uses the heart icon" do
      rendered = WantlistSave.render(@struct)
      assert rendered.icon == "heart"
    end

    test "renders from a plain map (DB reload path)" do
      rendered = WantlistSave.render(%{"track_name" => "One More Time", "artist_name" => "Daft Punk"})
      assert rendered.title == "One More Time"
      assert rendered.body == "Daft Punk"
      assert rendered.path == "/wantlist"
    end

    test "returns all required keys" do
      rendered = WantlistSave.render(@struct)
      assert Map.keys(rendered) |> Enum.sort() == [:body, :icon, :path, :title]
    end
  end
end
