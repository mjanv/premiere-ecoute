defmodule PremiereEcoute.Apis.TwitchClient do
  @moduledoc false

  use WebSockex

  def start_link(args) do
    WebSockex.start_link("wss://eventsub.wss.twitch.tv/ws", __MODULE__, args)
  end

  def handle_frame({:text, payload}, state) do
    IO.inspect(JSON.decode!(payload))
    {:ok, state}
  end

  def terminate(reason, state) do
    IO.puts("\nSocket Terminating:\n#{inspect(reason)}\n\n#{inspect(state)}\n")
    exit(:normal)
  end
end
