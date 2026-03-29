defmodule PremiereEcoute.Sessions.Scores.PollPipeline do
  @moduledoc """
  Broadway pipeline for processing Twitch poll updates.

  Processes PollUpdated events, transforms them into Poll aggregates, and upserts poll data for session retrospectives.
  """

  use Broadway

  require Logger

  alias Broadway.Message

  alias PremiereEcoute.Events.Chat.PollStarted
  alias PremiereEcoute.Events.Chat.PollUpdated
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Poll
  alias PremiereEcouteCore.Cache

  @doc """
  Starts the Broadway pipeline for Twitch poll processing.

  Initializes the pipeline with a single producer, processor, and batcher for handling poll update events with minimal batching.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [module: {PremiereEcouteCore.BroadwayProducer, []}, concurrency: 1],
      processors: [session: [concurrency: 1]],
      batchers: [
        writer: [
          concurrency: 1,
          batch_size: 1,
          batch_timeout: Application.get_env(:premiere_ecoute, :broadway_batch_timeout_ms, 1_000)
        ]
      ]
    )
  end

  @doc """
  Transforms PollUpdated events into Poll aggregates.

  Extracts poll data from the event, calculates total votes, and prepares the message for batched writing.
  """
  @spec handle_message(atom(), Message.t(), any()) :: Message.t()
  def handle_message(
        :session,
        %Message{data: %PollStarted{id: id, title: title, broadcaster_id: broadcaster_id, votes: votes}} = message,
        _
      ) do
    case Cache.get(:sessions, broadcaster_id) do
      {:ok, %{id: session_id, current_track_id: track_id}} when not is_nil(track_id) ->
        message
        |> Message.put_data(%Poll{
          poll_id: id,
          title: title,
          session_id: session_id,
          track_id: track_id,
          total_votes: 0,
          votes: votes
        })
        |> Message.put_batcher(:writer)

      _ ->
        Message.failed(message, :no_active_session)
    end
  end

  def handle_message(:session, %Message{data: %PollUpdated{id: id, votes: votes}} = message, _) do
    message
    |> Message.put_data(%Poll{poll_id: id, total_votes: Enum.sum(Map.values(votes)), votes: votes})
    |> Message.put_batcher(:writer)
  end

  @doc """
  Processes batches of poll data for database insertion.

  Upserts each poll in the batch to maintain the latest poll state for session retrospectives.
  """
  @spec handle_batch(atom(), [Message.t()], Broadway.BatchInfo.t(), any()) :: [Message.t()]
  def handle_batch(:writer, messages, _batch_info, _context) do
    messages
    |> Enum.map(fn message -> message.data end)
    |> Enum.each(fn poll ->
      case Poll.upsert(poll) do
        {:ok, saved} ->
          {:ok, report} = Report.generate(%ListeningSession{id: saved.session_id})
          summary = Enum.find(report.track_summaries, fn s -> s.track_id == saved.track_id end)

          if summary do
            PremiereEcoute.PubSub.broadcast("session:#{saved.session_id}", {:session_summary, summary})
          end

        _ ->
          :skip
      end
    end)

    messages
  end

  @doc """
  Handles failed message processing with error logging.

  Logs batch processing failures and returns failed messages for Broadway failure tracking.
  """
  @spec handle_failed([Message.t()], any()) :: [Message.t()]
  def handle_failed(messages, _context) do
    Logger.error("Cannot write a batch of #{length(messages)} messages")
    messages
  end
end
