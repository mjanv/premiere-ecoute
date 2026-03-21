defmodule PremiereEcoute.Playlists.Automations.ActionRegistryTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Playlists.Automations.ActionRegistry
  alias PremiereEcoute.Playlists.Automations.Actions.CreatePlaylist
  alias PremiereEcoute.Playlists.Automations.Actions.EmptyPlaylist
  alias PremiereEcoute.Playlists.Automations.Actions.RemoveDuplicates

  describe "get/1" do
    test "returns module for each registered action type" do
      assert {:ok, CreatePlaylist} = ActionRegistry.get("create_playlist")
      assert {:ok, EmptyPlaylist} = ActionRegistry.get("empty_playlist")
      assert {:ok, RemoveDuplicates} = ActionRegistry.get("remove_duplicates")
    end

    test "returns :error for unknown action type" do
      assert :error = ActionRegistry.get("unknown_action")
    end
  end

  describe "all/0" do
    test "returns all 7 actions" do
      assert map_size(ActionRegistry.all()) == 7
    end

    test "every registered module's id/0 matches its registry key" do
      for {type, mod} <- ActionRegistry.all() do
        assert mod.id() == type
      end
    end
  end
end
