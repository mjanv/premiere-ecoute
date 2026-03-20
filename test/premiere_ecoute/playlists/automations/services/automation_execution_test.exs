defmodule PremiereEcoute.Playlists.Automations.Services.AutomationExecutionTest do
  use PremiereEcoute.DataCase, async: true

  import Hammox

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Playlists.Automations.Automation
  alias PremiereEcoute.Playlists.Automations.AutomationRun
  alias PremiereEcoute.Playlists.Automations.Services.AutomationExecution

  setup :verify_on_exit!

  defp build_automation(user, steps) do
    {:ok, automation} =
      Automation.insert(user, %{
        name: "Test automation",
        schedule: :manual,
        steps: steps
      })

    automation
  end

  describe "run/2" do
    test "creates a completed run when all steps succeed" do
      user = user_fixture()

      expect(SpotifyApi, :get_playlist, fn "pl1" ->
        {:ok, %Playlist{provider: :spotify, playlist_id: "pl1", tracks: []}}
      end)

      automation =
        build_automation(user, [
          %{"position" => 1, "action_type" => "empty_playlist", "config" => %{"playlist_id" => "pl1"}}
        ])

      assert :ok = AutomationExecution.run(automation, 999)

      [run] = AutomationRun.list_for_automation(automation)
      assert run.status == :completed
      assert run.oban_job_id == 999
      assert run.started_at
      assert run.finished_at
      assert length(run.steps) == 1
      assert hd(run.steps)["status"] == "completed"
    end

    test "creates a failed run when a step errors, skips remaining steps" do
      user = user_fixture()

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:error, :api_error} end)

      automation =
        build_automation(user, [
          %{"position" => 1, "action_type" => "empty_playlist", "config" => %{"playlist_id" => "pl1"}},
          %{"position" => 2, "action_type" => "empty_playlist", "config" => %{"playlist_id" => "pl2"}}
        ])

      assert :ok = AutomationExecution.run(automation, 999)

      [run] = AutomationRun.list_for_automation(automation)
      assert run.status == :failed
      assert hd(run.steps)["status"] == "failed"
      assert Enum.at(run.steps, 1)["status"] == "skipped"
    end

    test "dispatches AutomationFailure notification on failure" do
      user = user_fixture()
      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "user:#{user.id}")

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:error, :api_error} end)

      automation =
        build_automation(user, [
          %{"position" => 1, "action_type" => "empty_playlist", "config" => %{"playlist_id" => "pl1"}}
        ])

      AutomationExecution.run(automation, 999)

      assert_receive {:user_notification, notification, rendered}
      assert notification.type == "automation_failure"
      assert rendered.title == "Automation failed: Test automation"
    end

    test "pipeline context accumulates outputs across steps" do
      user = user_fixture()

      # Two empty_playlist steps succeed; second one uses a different playlist
      expect(SpotifyApi, :get_playlist, 2, fn id ->
        {:ok, %Playlist{provider: :spotify, playlist_id: id, tracks: []}}
      end)

      automation =
        build_automation(user, [
          %{"position" => 1, "action_type" => "empty_playlist", "config" => %{"playlist_id" => "pl1"}},
          %{"position" => 2, "action_type" => "empty_playlist", "config" => %{"playlist_id" => "pl2"}}
        ])

      assert :ok = AutomationExecution.run(automation, 999)

      [run] = AutomationRun.list_for_automation(automation)
      assert run.status == :completed
      assert length(run.steps) == 2
    end

    test "unknown action_type fails the step" do
      user = user_fixture()

      automation =
        build_automation(user, [
          %{"position" => 1, "action_type" => "nonexistent_action", "config" => %{}}
        ])

      assert :ok = AutomationExecution.run(automation, 999)

      [run] = AutomationRun.list_for_automation(automation)
      assert run.status == :failed
      assert String.contains?(hd(run.steps)["error"], "unknown action_type")
    end
  end
end
