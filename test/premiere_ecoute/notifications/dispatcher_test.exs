defmodule PremiereEcoute.Notifications.DispatcherTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Notifications.Dispatcher
  alias PremiereEcoute.Notifications.Types.AutomationFailure

  @struct %AutomationFailure{automation_id: 1, automation_name: "My automation", run_id: 99}

  describe "dispatch/2" do
    test "persists a notification to the database" do
      user = user_fixture()

      assert {:ok, notification} = Dispatcher.dispatch(user, @struct)

      assert notification.id
      assert notification.user_id == user.id
      assert notification.type == "automation_failure"
      assert notification.data == %{automation_id: 1, automation_name: "My automation", run_id: 99}
      assert is_nil(notification.read_at)
    end

    test "broadcasts via PubSub for pubsub channel" do
      user = user_fixture()
      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "user:#{user.id}")

      {:ok, notification} = Dispatcher.dispatch(user, @struct)

      assert_receive {:notification, ^notification, rendered}
      assert rendered.title == "Automation failed: My automation"
      assert rendered.path == "/playlists/automations/1?run=99"
    end

    test "returns error for unknown struct type" do
      user = user_fixture()

      assert {:error, :unknown_type} = Dispatcher.dispatch(user, %{__struct__: UnknownType})
    end
  end
end
