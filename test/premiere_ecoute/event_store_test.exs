defmodule PremiereEcoute.Events.StoreTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Events.AccountCreated
  alias PremiereEcoute.Events.AccountDeleted
  alias PremiereEcoute.Events.Store

  setup do
    for stream <- ["users", "accounts", "players"] do
      Store.delete_stream(stream, :any_version, :hard)
    end

    :ok
  end

  describe "append/2" do
    test "add event to a default stream" do
      :ok = Store.append(%AccountCreated{id: UUID.uuid4()}, stream: "user")
    end
  end

  describe "read/2" do
    test "read events from a default stream" do
      user_id = UUID.uuid4()

      :ok = Store.append(%AccountCreated{id: user_id}, stream: "user")
      :ok = Store.append(%AccountDeleted{id: user_id}, stream: "user")

      events = Store.read("user-#{user_id}")

      assert events == [%AccountCreated{id: user_id}, %AccountDeleted{id: user_id}]
    end

    test "read events from a common stream" do
      :ok = Store.append(%AccountCreated{id: "id1"}, stream: "player")
      :ok = Store.append(%AccountCreated{id: "id2"}, stream: "player")
      :ok = Store.append(%AccountCreated{id: "id3"}, stream: "player")

      events = Store.read("players")

      assert events == [%AccountCreated{id: "id1"}, %AccountCreated{id: "id2"}, %AccountCreated{id: "id3"}]
    end
  end

  describe "paginate/2" do
    test "read events from a common stream" do
      for i <- 1..25 do
        :ok = Store.append(%AccountCreated{id: "id#{i}"}, stream: "account")
      end

      events1 = Store.paginate("accounts", page: 1, size: 10)
      events2 = Store.paginate("accounts", page: 2, size: 10)
      events3 = Store.paginate("accounts", page: 3, size: 10)

      assert length(events1) == 10
      assert length(events2) == 10
      assert length(events3) == 5

      assert %{
               event_number: 1,
               event_id: _,
               stream_uuid: "account-id1",
               stream_version: 1,
               event_type: "Elixir.PremiereEcoute.Events.AccountCreated",
               data: %AccountCreated{id: "id1"},
               metadata: %{},
               created_at: _
             } = hd(events1)

      assert %{
               event_number: 11,
               event_id: _,
               stream_uuid: "account-id11",
               stream_version: 1,
               event_type: "Elixir.PremiereEcoute.Events.AccountCreated",
               data: %AccountCreated{id: "id11"},
               metadata: %{},
               created_at: _
             } = hd(events2)

      assert %{
               event_number: 21,
               event_id: _,
               stream_uuid: "account-id21",
               stream_version: 1,
               event_type: "Elixir.PremiereEcoute.Events.AccountCreated",
               data: %AccountCreated{id: "id21"},
               metadata: %{},
               created_at: _
             } = hd(events3)
    end
  end

  describe "ok/2 & error/2" do
    test "An event can be dispatched on the {:ok, data} pattern on the user stream" do
      user_id = UUID.uuid4()

      out =
        {:ok, %{id: user_id}}
        |> Store.ok("user", fn data -> %AccountCreated{id: data.id} end)
        |> Store.error("user", fn reason -> %AccountDeleted{id: reason.id} end)

      events = Store.read("user-#{user_id}")

      assert out == {:ok, %{id: user_id}}
      assert events == [%AccountCreated{id: user_id}]
    end

    test "An event can be dispatched on the {:ok, data} pattern on common stream" do
      user_id = UUID.uuid4()

      out =
        {:ok, %{id: user_id}}
        |> Store.ok("user", fn data -> %AccountCreated{id: data.id} end)
        |> Store.error("user", fn reason -> %AccountDeleted{id: reason.id} end)

      events = Store.read("user-#{user_id}")

      assert out == {:ok, %{id: user_id}}
      assert events == [%AccountCreated{id: user_id}]
    end

    test "An event can be dispatched on the {:error, reason} pattern on common stream" do
      user_id = UUID.uuid4()

      out =
        {:error, %{id: user_id}}
        |> Store.ok("user", fn data -> %AccountCreated{id: data.id} end)
        |> Store.error("user", fn reason -> %AccountDeleted{id: reason.id} end)

      events = Store.read("user-#{user_id}")

      assert out == {:error, %{id: user_id}}
      assert events == [%AccountDeleted{id: user_id}]
    end
  end
end
