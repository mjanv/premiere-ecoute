defmodule PremiereEcoute.EventStoreTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.EventStore

  describe "append/2" do
    test "add event to a stream" do
      :ok = EventStore.append(%AccountCreated{id: UUID.uuid4()}, UUID.uuid4())
    end

    # test "add event to a default stream" do
    #   :ok = EventStore.append(%AccountCreated{id: UUID.uuid4()})
    # end
  end

  describe "read/2" do
    test "read events from a stream" do
      stream_uuid = UUID.uuid4()

      :ok = EventStore.append(%AccountCreated{id: "id1"}, stream_uuid)
      :ok = EventStore.append(%AccountCreated{id: "id2"}, stream_uuid)

      events = EventStore.read(stream_uuid)

      assert events == [%AccountCreated{id: "id1"}, %AccountCreated{id: "id2"}]
    end

    test "read events from a default stream" do
      stream_uuid = UUID.uuid4()

      :ok = EventStore.append(%AccountCreated{id: "id3"}, stream_uuid)
      :ok = EventStore.append(%AccountDeleted{id: "id3"}, stream_uuid)

      events = EventStore.read(stream_uuid)

      assert events == [%AccountCreated{id: "id3"}, %AccountDeleted{id: "id3"}]
    end
  end

  test "An event can be dispatched on the {:ok, data} pattern" do
    out =
      {:ok, %{id: "abc"}}
      |> EventStore.ok("a", fn data -> %AccountCreated{id: data.id} end)
      |> EventStore.error("a", fn _reason -> %AccountDeleted{} end)

    events = EventStore.read("a")

    assert out == {:ok, %{id: "abc"}}
    assert events == [%AccountCreated{id: "abc"}]
  end

  test "An event can be dispatched on the {:error, reason} pattern" do
    out =
      {:error, :closed}
      |> EventStore.ok("b", fn data -> %AccountCreated{id: data.id} end)
      |> EventStore.error("b", fn _reason -> %AccountDeleted{} end)

    events = EventStore.read("b")

    assert out == {:error, :closed}
    assert events == [%AccountDeleted{}]
  end

  test "Events can be dispatched on the {:ok, data} or {:error, reason} pattern" do
    out1 =
      {:error, :closed}
      |> EventStore.ok_or(
        "c",
        fn _data -> %AccountCreated{} end,
        fn _reason -> %AccountDeleted{} end
      )

    out2 =
      {:ok, %{id: "abc"}}
      |> EventStore.ok_or(
        "c",
        fn data -> %AccountCreated{id: data.id} end,
        fn _reason -> %AccountDeleted{} end
      )

    events = EventStore.read("c")

    assert out1 == {:error, :closed}
    assert out2 == {:ok, %{id: "abc"}}
    assert events == [%AccountDeleted{}, %AccountCreated{id: "abc"}]
  end
end
