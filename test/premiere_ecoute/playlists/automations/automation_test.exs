defmodule PremiereEcoute.Playlists.Automations.AutomationTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Playlists.Automations.Automation

  describe "changeset/2" do
    test "valid with required fields" do
      user = user_fixture()

      assert %{valid?: true} =
               Automation.changeset(%Automation{}, %{
                 user_id: user.id,
                 name: "My automation",
                 schedule_type: :manual
               })
    end

    test "invalid without name" do
      user = user_fixture()

      assert %{valid?: false, errors: errors} =
               Automation.changeset(%Automation{}, %{user_id: user.id, schedule_type: :manual})

      assert Keyword.has_key?(errors, :name)
    end

    test "invalid without schedule_type" do
      user = user_fixture()

      assert %{valid?: false, errors: errors} =
               Automation.changeset(%Automation{}, %{user_id: user.id, name: "Test"})

      assert Keyword.has_key?(errors, :schedule_type)
    end

    test "recurring requires valid cron_expression" do
      user = user_fixture()

      assert %{valid?: false, errors: errors} =
               Automation.changeset(%Automation{}, %{
                 user_id: user.id,
                 name: "Test",
                 schedule_type: :recurring,
                 cron_expression: "not a cron"
               })

      assert Keyword.has_key?(errors, :cron_expression)
    end

    test "recurring with valid cron_expression" do
      user = user_fixture()

      assert %{valid?: true} =
               Automation.changeset(%Automation{}, %{
                 user_id: user.id,
                 name: "Test",
                 schedule_type: :recurring,
                 cron_expression: "0 9 1 * *"
               })
    end
  end

  describe "insert/2" do
    test "persists a manual automation" do
      user = user_fixture()

      assert {:ok, automation} =
               Automation.insert(user, %{
                 name: "My automation",
                 schedule_type: :manual,
                 steps: [%{"position" => 1, "action_type" => "empty_playlist", "config" => %{"playlist_id" => "abc"}}]
               })

      assert automation.id
      assert automation.user_id == user.id
      assert automation.name == "My automation"
      assert automation.schedule_type == :manual
      assert automation.enabled == true
      assert length(automation.steps) == 1
    end
  end

  describe "list_for_user/1" do
    test "returns automations for the user" do
      user = user_fixture()
      {:ok, _} = Automation.insert(user, %{name: "First", schedule_type: :manual})
      {:ok, _} = Automation.insert(user, %{name: "Second", schedule_type: :manual})

      automations = Automation.list_for_user(user)
      assert length(automations) == 2
    end

    test "does not return other users automations" do
      user = user_fixture()
      other = user_fixture()
      {:ok, _} = Automation.insert(other, %{name: "Other", schedule_type: :manual})

      assert Automation.list_for_user(user) == []
    end
  end

  describe "update/2" do
    test "updates the automation" do
      user = user_fixture()
      {:ok, automation} = Automation.insert(user, %{name: "Original", schedule_type: :manual})

      assert {:ok, updated} = Automation.update(automation, %{name: "Renamed"})
      assert updated.name == "Renamed"
    end
  end
end
