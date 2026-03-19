defmodule PremiereEcoute.Notifications.RegistryTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Notifications.Registry
  alias PremiereEcoute.Notifications.Types.AutomationFailure

  describe "get/1" do
    test "returns the type module for a known struct" do
      assert {:ok, AutomationFailure} = Registry.get(%AutomationFailure{automation_id: 1, automation_name: "x", run_id: 1})
    end

    test "returns :error for an unknown struct" do
      assert :error = Registry.get(%URI{})
    end
  end

  describe "get_by_string/1" do
    test "returns the type module for a known type string" do
      assert {:ok, AutomationFailure} = Registry.get_by_string("automation_failure")
    end

    test "returns :error for an unknown type string" do
      assert :error = Registry.get_by_string("unknown_type")
    end

    test "get/1 and get_by_string/1 resolve to the same module" do
      struct = %AutomationFailure{automation_id: 1, automation_name: "x", run_id: 1}
      {:ok, by_struct} = Registry.get(struct)
      {:ok, by_string} = Registry.get_by_string("automation_failure")
      assert by_struct == by_string
    end
  end

  describe "all/0" do
    test "returns a map keyed by type string" do
      all = Registry.all()
      assert is_map(all)
      assert Map.has_key?(all, "automation_failure")
    end
  end
end
