defmodule PremiereEcoute.Notifications.Workers.NotificationPrunerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Notifications.Notification
  alias PremiereEcoute.Notifications.Types.AutomationFailure
  alias PremiereEcoute.Notifications.Workers.NotificationPruner

  @struct %AutomationFailure{automation_id: 1, automation_name: "Test", run_id: 1}

  defp insert_notification(user) do
    {:ok, n} = Notification.insert(user, AutomationFailure.type(), Map.from_struct(@struct))
    n
  end

  defp backdate(notification, days_ago) do
    inserted_at = DateTime.add(DateTime.utc_now(), -days_ago, :day) |> DateTime.truncate(:second)

    Oban.Testing.with_testing_mode(:manual, fn ->
      Repo.update_all(
        from(n in Notification, where: n.id == ^notification.id),
        set: [inserted_at: inserted_at]
      )
    end)
  end

  describe "perform/1" do
    test "deletes read notifications older than retention period" do
      user = user_fixture()
      n = insert_notification(user)

      {:ok, n} = Notification.mark_read(n)
      backdate(n, 31)

      assert :ok = perform_job(NotificationPruner, %{})

      assert Repo.get(Notification, n.id) == nil
    end

    test "keeps read notifications within the retention period" do
      user = user_fixture()
      n = insert_notification(user)

      {:ok, n} = Notification.mark_read(n)
      backdate(n, 10)

      assert :ok = perform_job(NotificationPruner, %{})

      assert Repo.get(Notification, n.id) != nil
    end

    test "never deletes unread notifications regardless of age" do
      user = user_fixture()
      n = insert_notification(user)

      backdate(n, 60)

      assert :ok = perform_job(NotificationPruner, %{})

      assert Repo.get(Notification, n.id) != nil
    end
  end
end
