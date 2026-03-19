defmodule PremiereEcoute.Notifications.Types.AutomationFailureTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Notifications.Types.AutomationFailure

  @struct %AutomationFailure{automation_id: 42, automation_name: "Monthly refresh", run_id: 99}

  describe "type/0" do
    test "returns the registered type string" do
      assert AutomationFailure.type() == "automation_failure"
    end
  end

  describe "channels/0" do
    test "declares pubsub as the only channel" do
      assert AutomationFailure.channels() == [:pubsub]
    end
  end

  describe "render/1" do
    test "includes the automation name in the title" do
      rendered = AutomationFailure.render(@struct)
      assert rendered.title == "Automation failed: Monthly refresh"
    end

    test "builds the correct path" do
      rendered = AutomationFailure.render(@struct)
      assert rendered.path == "/playlists/automations/42?run=99"
    end

    test "returns all required keys" do
      rendered = AutomationFailure.render(@struct)
      assert Map.keys(rendered) |> Enum.sort() == [:body, :icon, :path, :title]
    end
  end
end
