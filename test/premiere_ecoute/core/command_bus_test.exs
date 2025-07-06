defmodule PremiereEcoute.Core.CommandBusTest do
  use PremiereEcoute.DataCase

  import ExUnit.CaptureLog

  alias PremiereEcoute.Core.CommandBus

  defmodule CommandA do
    defstruct [:a]
  end

  defmodule CommandB do
    defstruct [:b]
  end

  defmodule CommandC do
    defstruct [:c]
  end

  defmodule EventA do
    defstruct [:a]
  end

  defmodule EventB do
    defstruct [:b]
  end

  defmodule Handler do
    use PremiereEcoute.Core.CommandBus.Handler

    command(PremiereEcoute.Core.CommandBusTest.CommandA)
    command(PremiereEcoute.Core.CommandBusTest.CommandB)

    require Logger

    def validate(%CommandA{a: a} = command) when a > 3, do: {:ok, command}
    def validate(%CommandA{}), do: {:error, :unknown}
    def validate(command), do: {:ok, command}

    def handle(%CommandA{a: 10} = command) do
      Logger.error("handle: #{inspect(command)}")
      {:ok, :state, [%EventA{a: 11}]}
    end

    def handle(%CommandA{a: a} = command) do
      Logger.error("handle: #{inspect(command)}")
      {:ok, [%EventA{a: a + 1}]}
    end

    def handle(%CommandB{b: b} = command) do
      Logger.error("handle: #{inspect(command)}")
      {:error, [%EventB{b: b + 1}]}
    end
  end

  defmodule EventDispatcher do
    use PremiereEcoute.Core.EventBus.Handler

    event(PremiereEcoute.Core.CommandBusTest.EventA)

    require Logger

    def dispatch(event) do
      Logger.error("dispatch: #{inspect(event)}")
    end
  end

  describe "apply/1" do
    test "1a" do
      {{:ok, events}, logs} = with_log(fn -> CommandBus.apply(%CommandA{a: 4}) end)

      assert events == [
               %PremiereEcoute.Core.CommandBusTest.EventA{a: 5}
             ]

      assert logs =~ "handle: %PremiereEcoute.Core.CommandBusTest.CommandA{a: 4}"
      assert logs =~ "dispatch: %PremiereEcoute.Core.CommandBusTest.EventA{a: 5}"
    end

    test "1b" do
      {{:ok, state, events}, logs} = with_log(fn -> CommandBus.apply(%CommandA{a: 10}) end)

      assert state == :state

      assert events == [
               %PremiereEcoute.Core.CommandBusTest.EventA{a: 11}
             ]

      assert logs =~ "handle: %PremiereEcoute.Core.CommandBusTest.CommandA{a: 10}"
      assert logs =~ "dispatch: %PremiereEcoute.Core.CommandBusTest.EventA{a: 11}"
    end

    test "2" do
      {{:error, :unknown}, logs} = with_log(fn -> CommandBus.apply(%CommandA{a: 0}) end)

      refute logs =~ "CommandA"
      refute logs =~ "EventA"
    end

    test "3" do
      {{:error, [event]}, logs} = with_log(fn -> CommandBus.apply(%CommandB{b: 1}) end)

      assert event == %PremiereEcoute.Core.CommandBusTest.EventB{b: 2}

      assert logs =~ "handle: %PremiereEcoute.Core.CommandBusTest.CommandB{b: 1}"
      assert logs =~ "[error] No registered handler for PremiereEcoute.Core.CommandBusTest.EventB"
    end

    test "4" do
      {{:error, :not_registered}, logs} = with_log(fn -> CommandBus.apply(%CommandC{c: 1}) end)

      assert logs =~
               "[error] No registered handler for PremiereEcoute.Core.CommandBusTest.CommandC"
    end
  end
end
