defmodule PremiereEcoute.Sessions.Scores.MessagePipeline do
  @moduledoc """
  Broadway pipeline for processing chat votes.

  Processes MessageSent events from chat, extracts vote values from messages, batches votes by session for bulk insertion, generates session summaries, and broadcasts real-time score updates via PubSub.
  """

  use Broadway

  alias Broadway.BatchInfo
  alias Broadway.Message

  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcouteCore.Cache
  alias PremiereEcouteCore.Tracing

  require Tracing

  @doc """
  Starts the Broadway pipeline for chat vote processing.

  Initializes the pipeline with a single producer, processor, and batcher for handling vote messages with batching support.
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
          batch_size: 5,
          batch_timeout: Application.get_env(:premiere_ecoute, :broadway_batch_timeout_ms, 1_000)
        ]
      ]
    )
  end

  @doc """
  Processes individual chat messages to extract votes.

  Transforms MessageSent events into vote data and assigns them to batchers grouped by session ID for efficient bulk insertion.
  """
  @spec handle_message(atom(), Message.t(), any()) :: Message.t()
  def handle_message(:session, message, _) do
    Tracing.with_context(message.metadata[:otel_ctx], fn ->
      Tracing.span "vote.process" do
        case process(message.data) do
          {:ok, vote} ->
            Tracing.set_attributes(%{
              "session.id" => vote.session_id,
              "track.id" => vote.track_id,
              "vote.value" => vote.value,
              "vote.outcome" => "accepted"
            })

            message
            |> Message.put_data(vote)
            |> Message.put_batch_key(vote.session_id)
            |> Message.put_batcher(:writer)
            |> put_trace_context()

          {:error, reason} ->
            Tracing.set_attributes(%{"vote.outcome" => "rejected"})

            Message.failed(message, reason)
        end
      end
    end)
  end

  # Re-points the message context at the `vote.process` span, so that the batch span links back to
  # the per-vote work rather than to the webhook span that produced it.
  defp put_trace_context(%Message{} = message) do
    %{message | metadata: Map.put(message.metadata, :otel_ctx, Tracing.context())}
  end

  @doc """
  Extracts vote data from chat message event.

  Validates that the session has an active track, parses the vote value from the message text, and constructs a vote map with all required fields including timestamps.
  """
  @spec process(MessageSent.t()) :: {:ok, map()} | {:error, term()}
  def process(%MessageSent{broadcaster_id: broadcaster_id, user_id: user_id, message: message, is_streamer: is_streamer}) do
    with {:ok, %{current_track_id: track_id} = session} when not is_nil(track_id) <-
           Cache.get(:sessions, broadcaster_id),
         {:ok, value} <-
           Vote.from_message(message, session.vote_options),
         now <- DateTime.truncate(DateTime.utc_now(), :second),
         vote <- %{
           viewer_id: user_id,
           session_id: session.id,
           track_id: track_id,
           value: value,
           is_streamer: is_streamer,
           updated_at: now,
           inserted_at: now
         } do
      {:ok, vote}
    else
      _ -> {:error, nil}
    end
  end

  @doc """
  Processes batched votes for bulk insertion and broadcasts session summaries.

  Inserts all votes in the batch, generates an updated session report, extracts the relevant track summary, and broadcasts it via PubSub for real-time UI updates.
  """
  @spec handle_batch(atom(), [Message.t()], BatchInfo.t(), any()) :: [Message.t()]
  def handle_batch(:writer, messages, %BatchInfo{batch_key: session_id}, _context) do
    links = Tracing.links(Enum.map(messages, fn message -> message.metadata[:otel_ctx] end))

    Tracing.span "vote.batch_write",
      links: links,
      attributes: %{"session.id" => session_id, "batch.size" => length(messages)} do
      Tracing.span "vote.insert_all", attributes: %{"db.rows" => length(messages)} do
        Vote.create_all(Enum.map(messages, fn message -> message.data end), on_conflict: :nothing)
      end

      {:ok, report} =
        Tracing.span "report.generate", attributes: %{"session.id" => session_id} do
          {:ok, report} = Report.generate(%ListeningSession{id: session_id})
          Tracing.set_attributes(%{"report.track_count" => length(report.track_summaries)})

          {:ok, report}
        end

      track_id = hd(messages).data.track_id
      summary = Enum.find(report.track_summaries, fn s -> s.track_id == track_id end)

      if summary do
        Tracing.span "session_summary.broadcast", attributes: %{"pubsub.topic" => "session:#{session_id}"} do
          PremiereEcoute.PubSub.broadcast("session:#{session_id}", {:session_summary, summary})
        end
      end

      messages
    end
  end

  @doc """
  Handles failed message processing.

  Returns failed messages without further processing to allow Broadway to manage failure tracking and retries.
  """
  @spec handle_failed([Message.t()], any()) :: [Message.t()]
  def handle_failed(messages, _context), do: messages
end
