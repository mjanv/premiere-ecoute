defmodule PremiereEcoute.AutomationsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Automations
  alias PremiereEcoute.Playlists.Automations.Automation

  defp automation_fixture(user, steps) do
    {:ok, automation} =
      Automation.create(%{
        user_id: user.id,
        name: "Test automation",
        schedule: :manual,
        steps: steps
      })

    automation
  end

  describe "automation_counts/2" do
    test "counts automations referencing a playlist under a scalar :playlist_id key (e.g. shuffle_playlist)" do
      user = user_fixture()

      automation_fixture(user, [
        %{"position" => 0, "action_type" => "shuffle_playlist", "config" => %{"playlist" => "abc123"}}
      ])

      counts = Automations.automation_counts(user, ["abc123"])

      assert counts == %{"abc123" => 1}
    end

    test "counts automations referencing a playlist as a copy_playlist source or target" do
      user = user_fixture()

      automation_fixture(user, [
        %{
          "position" => 0,
          "action_type" => "copy_playlist",
          "config" => %{"source" => "src1", "target" => "tgt1"}
        }
      ])

      counts = Automations.automation_counts(user, ["src1", "tgt1"])

      assert counts == %{"src1" => 1, "tgt1" => 1}
    end

    test "counts automations referencing a playlist inside a merge_playlists sources list" do
      user = user_fixture()

      automation_fixture(user, [
        %{
          "position" => 0,
          "action_type" => "merge_playlists",
          "config" => %{"sources" => ["a", "b", "c"], "target" => "tgt"}
        }
      ])

      counts = Automations.automation_counts(user, ["a", "b", "c", "tgt"])

      assert counts == %{"a" => 1, "b" => 1, "c" => 1, "tgt" => 1}
    end

    test "counts a playlist referenced across multiple automations" do
      user = user_fixture()

      automation_fixture(user, [%{"position" => 0, "action_type" => "shuffle_playlist", "config" => %{"playlist" => "shared"}}])
      automation_fixture(user, [%{"position" => 0, "action_type" => "empty_playlist", "config" => %{"playlist" => "shared"}}])

      counts = Automations.automation_counts(user, ["shared"])

      assert counts == %{"shared" => 2}
    end

    test "does not count a playlist_id that isn't referenced" do
      user = user_fixture()

      automation_fixture(user, [
        %{"position" => 0, "action_type" => "shuffle_playlist", "config" => %{"playlist" => "abc123"}}
      ])

      counts = Automations.automation_counts(user, ["unrelated"])

      assert counts == %{}
    end

    test "does not count automations belonging to another user" do
      user = user_fixture()
      other = user_fixture()

      automation_fixture(other, [
        %{"position" => 0, "action_type" => "shuffle_playlist", "config" => %{"playlist" => "abc123"}}
      ])

      counts = Automations.automation_counts(user, ["abc123"])

      assert counts == %{}
    end

    test "returns an empty map for an empty playlist_ids list" do
      user = user_fixture()

      assert Automations.automation_counts(user, []) == %{}
    end

    test "counts a playlist via notify_subscribers, a different scalar :playlist action than shuffle_playlist" do
      user = user_fixture()

      automation_fixture(user, [
        %{"position" => 0, "action_type" => "notify_subscribers", "config" => %{"playlist" => "abc123"}}
      ])

      counts = Automations.automation_counts(user, ["abc123"])

      assert counts == %{"abc123" => 1}
    end

    test "counts each matching step once within a single automation with mixed steps" do
      user = user_fixture()

      automation_fixture(user, [
        %{"position" => 0, "action_type" => "shuffle_playlist", "config" => %{"playlist" => "target_pl"}},
        %{"position" => 1, "action_type" => "notify_subscribers", "config" => %{"playlist" => "unrelated_pl"}},
        %{
          "position" => 2,
          "action_type" => "copy_playlist",
          "config" => %{"source" => "target_pl", "target" => "other_pl"}
        }
      ])

      counts = Automations.automation_counts(user, ["target_pl", "unrelated_pl", "other_pl"])

      # target_pl appears in two different steps of the same automation but should only
      # count once per automation (Enum.uniq() before the reduce), not once per occurrence.
      assert counts == %{"target_pl" => 1, "unrelated_pl" => 1, "other_pl" => 1}
    end
  end

  describe "list_for_playlist/2" do
    test "finds an automation referencing a playlist under a scalar key" do
      user = user_fixture()

      automation =
        automation_fixture(user, [
          %{"position" => 0, "action_type" => "shuffle_playlist", "config" => %{"playlist" => "abc123"}}
        ])

      assert [%Automation{id: id}] = Automations.list_for_playlist(user, "abc123")
      assert id == automation.id
    end

    test "finds an automation referencing a playlist inside a merge_playlists sources list" do
      user = user_fixture()

      automation =
        automation_fixture(user, [
          %{
            "position" => 0,
            "action_type" => "merge_playlists",
            "config" => %{"sources" => ["a", "b"], "target" => "tgt"}
          }
        ])

      assert [%Automation{id: id}] = Automations.list_for_playlist(user, "b")
      assert id == automation.id
    end

    test "returns an empty list when the playlist isn't referenced by any automation" do
      user = user_fixture()

      automation_fixture(user, [
        %{"position" => 0, "action_type" => "shuffle_playlist", "config" => %{"playlist" => "abc123"}}
      ])

      assert Automations.list_for_playlist(user, "unrelated") == []
    end

    test "finds an automation when only one of several steps references the playlist" do
      user = user_fixture()

      automation =
        automation_fixture(user, [
          %{"position" => 0, "action_type" => "notify_subscribers", "config" => %{"playlist" => "unrelated_pl"}},
          %{
            "position" => 1,
            "action_type" => "merge_playlists",
            "config" => %{"sources" => ["a", "b"], "target" => "tgt"}
          }
        ])

      assert [%Automation{id: id}] = Automations.list_for_playlist(user, "b")
      assert id == automation.id
    end

    test "does not return an automation whose steps reference a different playlist entirely" do
      user = user_fixture()

      automation_fixture(user, [
        %{"position" => 0, "action_type" => "notify_subscribers", "config" => %{"playlist" => "unrelated_pl"}},
        %{
          "position" => 1,
          "action_type" => "merge_playlists",
          "config" => %{"sources" => ["a", "b"], "target" => "tgt"}
        }
      ])

      assert Automations.list_for_playlist(user, "not_present_anywhere") == []
    end
  end
end
