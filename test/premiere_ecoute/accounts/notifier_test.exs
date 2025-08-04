defmodule PremiereEcoute.Accounts.NotifierTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Events.AccountCreated
  alias PremiereEcoute.Events.AccountDeleted
  alias PremiereEcoute.Events.ChannelFollowed
  alias PremiereEcoute.EventStore
  alias PremiereEcoute.Mailer.Mock, as: Mailer

  setup do
    {:ok, pid} = start_supervised(PremiereEcoute.Accounts.Notifier)
    ref = Process.monitor(pid)

    Application.put_env(:premiere_ecoute, :mailer, PremiereEcoute.Mailer.Mock)

    {:ok, %{ref: ref, pid: pid}}
  end

  describe "Notifier" do
    test "dispatch an email event on AccountCreated" do
      event = %AccountCreated{id: 1}
      expect(Mailer, :dispatch, fn ^event -> :ok end)

      EventStore.append(event, stream: "user")

      :timer.sleep(100)
    end

    test "dispatch an email event on AccountDeleted" do
      event = %AccountDeleted{id: 1}
      expect(Mailer, :dispatch, fn ^event -> :ok end)

      EventStore.append(event, stream: "user")

      :timer.sleep(100)
    end

    test "does not dispatch an email event on other events", %{ref: ref, pid: pid} do
      event = %ChannelFollowed{id: 1}

      expect(Mailer, :dispatch, 0, fn _ -> :ok end)
      EventStore.append(event, stream: "user")

      refute_receive {:DOWN, ^ref, :process, ^pid, {%Mox.UnexpectedCallError{}, _}}, 100
    end
  end
end
