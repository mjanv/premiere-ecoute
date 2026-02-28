defmodule PremiereEcouteCore.EventBusTest do
  use PremiereEcoute.DataCase, async: true

  import ExUnit.CaptureLog

  alias PremiereEcouteCore.EventBus

  defmodule EventA do
    defstruct [:a]
  end

  defmodule EventB do
    defstruct [:b]
  end

  defmodule EventC do
    defstruct [:c]
  end

  defmodule Handler do
    use PremiereEcouteCore.EventBus.Handler

    event(PremiereEcouteCore.EventBusTest.EventA)
    event(PremiereEcouteCore.EventBusTest.EventB)

    require Logger

    def dispatch(%EventA{} = command) do
      Logger.error("dispatch: #{inspect(command)}")
      :ok
    end

    def dispatch(%EventB{} = command) do
      Logger.error("dispatch: #{inspect(command)}")
      :ok
    end
  end

  describe "dispatch/1" do
    test "1" do
      {:ok, logs} = with_log(fn -> EventBus.dispatch(%EventA{a: 5}) end)

      assert logs =~ "dispatch: %PremiereEcouteCore.EventBusTest.EventA{a: 5}"
    end

    test "2" do
      {:ok, logs1} = with_log(fn -> EventBus.dispatch(%EventA{a: 5}) end)
      {:ok, logs2} = with_log(fn -> EventBus.dispatch(%EventB{b: 5}) end)
      {{:error, :not_registered}, logs3} = with_log(fn -> EventBus.dispatch(%EventC{c: 5}) end)

      assert logs1 =~ "dispatch: %PremiereEcouteCore.EventBusTest.EventA{a: 5}"
      assert logs2 =~ "dispatch: %PremiereEcouteCore.EventBusTest.EventB{b: 5}"
      refute logs3 =~ "dispatch: %PremiereEcouteCore.EventBusTest.EventC{c: 5}"
    end

    test "3" do
      {:ok, logs} =
        with_log(fn ->
          events = [%EventA{a: 5}, %EventB{b: 5}, %EventC{c: 5}]
          EventBus.dispatch(events)
        end)

      assert logs =~ "dispatch: %PremiereEcouteCore.EventBusTest.EventA{a: 5}"
      assert logs =~ "dispatch: %PremiereEcouteCore.EventBusTest.EventB{b: 5}"
      refute logs =~ "dispatch: %PremiereEcouteCore.EventBusTest.EventC{c: 5}"
    end
  end
end
