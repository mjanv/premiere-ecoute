defmodule PremiereEcoute.Notifications.NotificationTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Notifications.Notification

  @valid_data %{"automation_id" => 1, "automation_name" => "My automation", "run_id" => 99}

  describe "changeset/2" do
    test "valid with required fields" do
      user = user_fixture()

      changeset =
        Notification.changeset(%Notification{}, %{
          user_id: user.id,
          type: "automation_failure",
          data: @valid_data
        })

      assert changeset.valid?
    end

    test "invalid without type" do
      user = user_fixture()
      changeset = Notification.changeset(%Notification{}, %{user_id: user.id, data: @valid_data})

      refute changeset.valid?
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without user_id" do
      changeset =
        Notification.changeset(%Notification{}, %{
          type: "automation_failure",
          data: @valid_data
        })

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "read_changeset/2" do
    test "sets read_at" do
      user = user_fixture()
      {:ok, notification} = Notification.insert(user, "automation_failure", @valid_data)
      read_at = DateTime.utc_now(:second)

      changeset = Notification.read_changeset(notification, read_at)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :read_at) == read_at
    end
  end

  describe "insert/3" do
    test "persists a notification for the user" do
      user = user_fixture()

      assert {:ok, notification} = Notification.insert(user, "automation_failure", @valid_data)

      assert notification.id
      assert notification.user_id == user.id
      assert notification.type == "automation_failure"
      assert notification.data == @valid_data
      assert is_nil(notification.read_at)
    end

    test "returns changeset error for nil type" do
      user = user_fixture()

      assert {:error, changeset} = Notification.insert(user, nil, %{"foo" => "bar"})
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "mark_read/1" do
    test "sets read_at on the notification" do
      user = user_fixture()
      {:ok, notification} = Notification.insert(user, "automation_failure", @valid_data)

      assert is_nil(notification.read_at)

      assert {:ok, updated} = Notification.mark_read(notification)
      assert %DateTime{} = updated.read_at
    end
  end

  describe "mark_all_read/1" do
    test "marks all unread notifications for the user as read" do
      user = user_fixture()
      other = user_fixture()

      {:ok, _} = Notification.insert(user, "automation_failure", @valid_data)
      {:ok, _} = Notification.insert(user, "automation_failure", @valid_data)
      {:ok, other_n} = Notification.insert(other, "automation_failure", @valid_data)

      :ok = Notification.mark_all_read(user)

      assert Notification.unread_count(user) == 0
      assert Notification.unread_count(other) == 1
      assert is_nil(Repo.get!(Notification, other_n.id).read_at)
    end
  end

  describe "list_unread/1" do
    test "returns only unread notifications for the user" do
      user = user_fixture()
      other = user_fixture()

      {:ok, n1} = Notification.insert(user, "automation_failure", @valid_data)
      {:ok, _} = Notification.insert(other, "automation_failure", @valid_data)
      {:ok, n3} = Notification.insert(user, "automation_failure", @valid_data)

      Notification.mark_read(n1)

      unread = Notification.list_unread(user)
      ids = Enum.map(unread, & &1.id)

      assert n3.id in ids
      refute n1.id in ids
      refute Enum.any?(unread, &(&1.user_id == other.id))
    end

    test "returns notifications ordered by most recent first" do
      user = user_fixture()

      {:ok, n1} = Notification.insert(user, "automation_failure", @valid_data)
      {:ok, n2} = Notification.insert(user, "automation_failure", @valid_data)

      [first | _] = Notification.list_unread(user)
      assert first.id == n2.id
      assert n1.id != n2.id
    end
  end

  describe "unread_count/1" do
    test "returns correct unread count" do
      user = user_fixture()

      {:ok, n1} = Notification.insert(user, "automation_failure", @valid_data)
      {:ok, _} = Notification.insert(user, "automation_failure", @valid_data)

      assert Notification.unread_count(user) == 2

      Notification.mark_read(n1)

      assert Notification.unread_count(user) == 1
    end
  end
end
