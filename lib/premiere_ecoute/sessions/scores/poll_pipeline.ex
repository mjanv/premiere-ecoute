defmodule PremiereEcoute.Sessions.Scores.PollPipeline do
  @moduledoc false

  use Broadway

  require Logger

  alias Broadway.Message

  alias PremiereEcoute.Events.Chat.PollUpdated
  alias PremiereEcoute.Sessions.Scores.Poll

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [module: {PremiereEcouteCore.BroadwayProducer, []}, concurrency: 1],
      processors: [session: [concurrency: 1]],
      batchers: [writer: [concurrency: 1, batch_size: 1, batch_timeout: 1_000]]
    )
  end

  def handle_message(:session, %Message{data: %PollUpdated{id: id, votes: votes}} = message, _) do
    message
    |> Message.put_data(%Poll{poll_id: id, total_votes: Enum.sum(Map.values(votes)), votes: votes})
    |> Message.put_batcher(:writer)
  end

  def handle_batch(:writer, messages, _batch_info, _context) do
    messages
    |> Enum.map(fn message -> message.data end)
    |> Enum.each(&Poll.upsert/1)

    messages
  end

  def handle_failed(messages, _context) do
    Logger.error("Cannot write a batch of #{length(messages)} messages")
    messages
  end
end
