defmodule PremiereEcouteMock.TwitchApi.PollSimulator do
  @moduledoc """
  Simulates Twitch poll progress webhooks during development.

  When a poll is started via the mock server, this GenServer tracks it and sends
  a `channel.poll.progress` webhook to the main app every 5 seconds with random
  vote increments. Stops automatically when the poll is ended.
  """

  use GenServer

  require Logger

  @interval_ms 5_000
  @webhook_url "http://localhost:4000/webhooks/twitch"
  @secret Application.compile_env(:premiere_ecoute, :twitch_eventsub_secret)

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc "Register a new poll and start sending progress events."
  @spec start_poll(String.t(), String.t(), String.t(), [String.t()]) :: :ok
  def start_poll(poll_id, broadcaster_id, title, choices) do
    GenServer.cast(__MODULE__, {:start_poll, poll_id, broadcaster_id, title, choices})
  end

  @doc "Stop sending progress events for the given poll."
  @spec end_poll(String.t()) :: :ok
  def end_poll(poll_id) do
    GenServer.cast(__MODULE__, {:end_poll, poll_id})
  end

  @impl GenServer
  def init(state), do: {:ok, state}

  @impl GenServer
  def handle_cast({:start_poll, poll_id, broadcaster_id, title, choices}, state) do
    # Drop any existing polls for the same broadcaster before starting a new one
    state =
      state
      |> Enum.reject(fn {_id, p} -> p.broadcaster_id == broadcaster_id end)
      |> Map.new()

    Logger.info("PollSimulator: starting poll #{poll_id} \"#{title}\"")

    poll = %{
      broadcaster_id: broadcaster_id,
      title: title,
      choices: Enum.map(choices, fn c -> %{title: c["title"], votes: 0} end)
    }

    send_begin(poll_id, poll)
    Process.send_after(self(), {:tick, poll_id}, @interval_ms)

    {:noreply, Map.put(state, poll_id, poll)}
  end

  @impl GenServer
  def handle_cast({:end_poll, poll_id}, state) do
    Logger.info("PollSimulator: stopping progress for poll #{poll_id}")
    {:noreply, Map.delete(state, poll_id)}
  end

  @impl GenServer
  def handle_info({:tick, poll_id}, state) do
    case Map.get(state, poll_id) do
      nil ->
        Logger.info("PollSimulator: no poll found")
        {:noreply, state}

      poll ->
        updated_poll = %{
          poll
          | choices:
              Enum.map(poll.choices, fn c ->
                %{c | votes: c.votes + Enum.random(0..10)}
              end)
        }

        vote_summary = Enum.map_join(updated_poll.choices, ", ", fn c -> "#{c.title}: #{c.votes}" end)
        Logger.info("PollSimulator: tick for poll #{poll_id} [#{vote_summary}]")

        send_progress(poll_id, updated_poll)
        Process.send_after(self(), {:tick, poll_id}, @interval_ms)

        {:noreply, Map.put(state, poll_id, updated_poll)}
    end
  end

  defp send_begin(poll_id, poll) do
    send_webhook(poll_id, poll, "channel.poll.begin", poll.choices)
    Logger.info("PollSimulator: begin webhook delivered for #{poll_id}")
  end

  defp send_progress(poll_id, poll) do
    send_webhook(poll_id, poll, "channel.poll.progress", poll.choices)
    Logger.info("PollSimulator: progress webhook delivered for #{poll_id}")
  end

  defp send_webhook(poll_id, poll, event_type, choices) do
    msg_id = "mock-#{System.unique_integer([:positive])}"
    timestamp = DateTime.to_iso8601(DateTime.utc_now())

    formatted_choices =
      Enum.map(choices, fn c ->
        %{"title" => c.title, "votes" => c.votes, "bits_votes" => 0, "channel_points_votes" => 0}
      end)

    body =
      Jason.encode!(%{
        "subscription" => %{"type" => event_type},
        "event" => %{
          "id" => poll_id,
          "broadcaster_user_id" => poll.broadcaster_id,
          "title" => poll.title,
          "choices" => formatted_choices
        }
      })

    sig = signature(msg_id <> timestamp <> body)

    case Req.post(@webhook_url,
           body: body,
           headers: [
             {"content-type", "application/json"},
             {"twitch-eventsub-message-id", msg_id},
             {"twitch-eventsub-message-timestamp", timestamp},
             {"twitch-eventsub-message-type", "notification"},
             {"twitch-eventsub-message-signature", sig}
           ]
         ) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status}} -> Logger.warning("PollSimulator: webhook #{event_type} got HTTP #{status}")
      {:error, reason} -> Logger.warning("PollSimulator: webhook #{event_type} failed: #{inspect(reason)}")
    end
  end

  defp signature(message) do
    :crypto.mac(:hmac, :sha256, @secret, message)
    |> Base.encode16(case: :lower)
    |> then(&("sha256=" <> &1))
  end
end
