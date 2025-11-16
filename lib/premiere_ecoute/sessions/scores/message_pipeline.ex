defmodule PremiereEcoute.Sessions.Scores.MessagePipeline do
  @moduledoc """
  Broadway pipeline for processing chat votes.

  Processes MessageSent events from chat, extracts vote values from messages, batches votes by session for bulk insertion, generates session summaries, and broadcasts real-time score updates via PubSub.
  """

  use Broadway

  require Logger

  alias Broadway.BatchInfo
  alias Broadway.Message

  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcouteCore.Cache

  @batch_timeout Application.compile_env(:premiere_ecoute, PremiereEcoute.Sessions)[:batch_timeout]

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
      batchers: [writer: [concurrency: 1, batch_size: 5, batch_timeout: @batch_timeout]]
    )
  end

  @doc """
  Processes individual chat messages to extract votes.

  Transforms MessageSent events into vote data and assigns them to batchers grouped by session ID for efficient bulk insertion.
  """
  @spec handle_message(atom(), Message.t(), any()) :: Message.t()
  def handle_message(:session, message, _) do
    case process(message.data) do
      {:ok, vote} -> message |> Message.put_data(vote) |> Message.put_batch_key(vote.session_id) |> Message.put_batcher(:writer)
      {:error, reason} -> message |> Message.failed(reason)
    end
  end

  @doc """
  Extracts vote data from chat message event.

  Validates that the session has an active track, parses the vote value from the message text, and constructs a vote map with all required fields including timestamps.
  """
  @spec process(MessageSent.t()) :: {:ok, map()} | {:error, term()}
  def process(%MessageSent{broadcaster_id: broadcaster_id, user_id: user_id, message: message, is_streamer: is_streamer}) do
    with {:ok, %{current_track_id: track_id} = session} when not is_nil(track_id) <- Cache.get(:sessions, broadcaster_id),
         {:ok, value} <- Vote.from_message(message, session.vote_options),
         now <- DateTime.utc_now(),
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
    messages
    |> Enum.map(fn message -> message.data end)
    |> Enum.group_by(fn vote -> {vote.viewer_id, vote.track_id} end)
    |> Enum.map(fn {_key, votes} ->
      latest_vote = Enum.max_by(votes, fn vote -> vote.updated_at end, DateTime)

      %{
        latest_vote
        | updated_at: DateTime.truncate(latest_vote.updated_at, :second),
          inserted_at: DateTime.truncate(latest_vote.inserted_at, :second)
      }
    end)
    |> Vote.create_all(
      on_conflict: {:replace, [:value, :updated_at]},
      conflict_target: [:viewer_id, :session_id, :track_id]
    )

    {:ok, report} = Report.generate(%ListeningSession{id: session_id})

    track_id = hd(messages).data.track_id
    summary = Enum.find(report.track_summaries, fn s -> s.track_id == track_id end)

    if summary do
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", {:session_summary, summary})
    end

    messages
  end

  @doc """
  Handles failed message processing.

  Returns failed messages without further processing to allow Broadway to manage failure tracking and retries.
  """
  @spec handle_failed([Message.t()], any()) :: [Message.t()]
  def handle_failed(messages, _context), do: messages
end
