defmodule PremiereEcoute.EventStoreTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.EventStore

  describe "append/2" do
    test "add event to a stream" do
      :ok = EventStore.append(%UserCreated{id: "id"}, UUID.uuid4())
    end
  end

  describe "read/2" do
    test "read events from a stream" do
      stream_uuid = UUID.uuid4()

      :ok = EventStore.append(%UserCreated{id: "id1"}, stream_uuid)
      :ok = EventStore.append(%UserCreated{id: "id2"}, stream_uuid)

      events = EventStore.read(stream_uuid)

      assert events == [%UserCreated{id: "id1"}, %UserCreated{id: "id2"}]
    end
  end

  test "An event can be dispatched on the {:ok, data} pattern" do
    out =
      {:ok, %{id: "abc"}}
      |> EventStore.ok("a", fn data -> %UserCreated{id: data.id} end)
      |> EventStore.error("a", fn _reason -> %UserNotCreated{} end)

    events = EventStore.read("a")

    assert out == {:ok, %{id: "abc"}}
    assert events == [%UserCreated{id: "abc"}]
  end

  test "An event can be dispatched on the {:error, reason} pattern" do
    out =
      {:error, :closed}
      |> EventStore.ok("b", fn data -> %UserCreated{id: data.id} end)
      |> EventStore.error("b", fn _reason -> %UserNotCreated{} end)

    events = EventStore.read("b")

    assert out == {:error, :closed}
    assert events == [%UserNotCreated{}]
  end

  test "Events can be dispatched on the {:ok, data} or {:error, reason} pattern" do
    out1 =
      {:error, :closed}
      |> EventStore.ok_or(
        "c",
        fn _data -> %UserCreated{} end,
        fn _reason -> %UserNotCreated{} end
      )

    out2 =
      {:ok, %{id: "abc"}}
      |> EventStore.ok_or(
        "c",
        fn data -> %UserCreated{id: data.id} end,
        fn _reason -> %UserNotCreated{} end
      )

    events = EventStore.read("c")

    assert out1 == {:error, :closed}
    assert out2 == {:ok, %{id: "abc"}}
    assert events == [%UserNotCreated{}, %UserCreated{id: "abc"}]
  end
end
