defmodule PremiereEcoute.Sessions.Scores.MessagePipeline do
  @moduledoc """
  Broadway pipeline for processing chat votes.

  Processes MessageSent events from chat, extracts vote values from messages, batches votes by session for bulk insertion, generates session summaries, and broadcasts real-time score updates via PubSub.
  """

  use Broadway

  alias Broadway.BatchInfo
  alias Broadway.Message

  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcouteCore.Cache

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
    case process(message.data) do
      {:ok, vote} -> message |> Message.put_data(vote) |> Message.put_batch_key(vote.session_id) |> Message.put_batcher(:writer)
      {:error, reason} -> message |> Message.failed(reason)
    end
  end

  @doc """
  Extracts vote data from chat message event.

  Validates that the session has an active track, or an open album vote, parses the vote value from the message text, and constructs a vote map with all required fields including timestamps.
  """
  @spec process(MessageSent.t()) :: {:ok, map()} | {:error, term()}
  def process(%MessageSent{broadcaster_id: broadcaster_id, user_id: user_id, message: message, is_streamer: is_streamer}) do
    with {:ok, session} when not is_nil(session) <- Cache.get(:sessions, broadcaster_id),
         {:ok, scope, track_id} <- vote_target(session),
         {:ok, value} <-
           Vote.from_message(message, session.vote_options),
         now <- DateTime.truncate(DateTime.utc_now(), :second),
         vote <- %{
           viewer_id: user_id,
           session_id: session.id,
           track_id: track_id,
           scope: scope,
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

  defp vote_target(%{vote_scope: :album}), do: {:ok, :album, nil}
  defp vote_target(%{current_track_id: track_id}) when not is_nil(track_id), do: {:ok, :track, track_id}
  defp vote_target(_session), do: {:error, :no_track}

  @doc """
  Processes batched votes for bulk insertion and broadcasts session summaries.

  Inserts all votes in the batch, generates an updated session report, extracts the relevant track summary (or the session summary for album votes), and broadcasts it via PubSub for real-time UI updates.
  """
  @spec handle_batch(atom(), [Message.t()], BatchInfo.t(), any()) :: [Message.t()]
  def handle_batch(:writer, messages, %BatchInfo{batch_key: session_id}, _context) do
    Vote.create_all(Enum.map(messages, fn message -> message.data end), on_conflict: :nothing)

    # The report needs the session vote options to compute scores of text vote scales (smash/pass).
    {:ok, report} = Report.generate(Repo.get(ListeningSession, session_id) || %ListeningSession{id: session_id})

    summary =
      case hd(messages).data do
        %{scope: :album} -> report.session_summary
        %{track_id: track_id} -> Enum.find(report.track_summaries, fn s -> s.track_id == track_id end)
      end

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
