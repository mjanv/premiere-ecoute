defmodule PremiereEcoute.Sessions.Scores.MessagePipeline do
  @moduledoc false

  use Broadway

  require Logger

  alias Broadway.BatchInfo
  alias Broadway.Message

  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcouteCore.Cache

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [module: {PremiereEcouteCore.BroadwayProducer, []}, concurrency: 1],
      processors: [session: [concurrency: 1]],
      batchers: [writer: [concurrency: 1, batch_size: 5, batch_timeout: 1_000]]
    )
  end

  def handle_message(:session, message, _) do
    case process(message.data) do
      {:ok, vote} -> message |> Message.put_data(vote) |> Message.put_batch_key(vote.session_id) |> Message.put_batcher(:writer)
      {:error, reason} -> message |> Message.failed(reason)
    end
  end

  def process(%MessageSent{broadcaster_id: broadcaster_id, user_id: user_id, message: message, is_streamer: is_streamer}) do
    with {:ok, {session_id, vote_options, track_id}} when not is_nil(track_id) <- Cache.get(:sessions, broadcaster_id),
         {:ok, value} <- Vote.from_message(message, vote_options),
         now <- DateTime.truncate(DateTime.utc_now(), :second),
         vote <- %{
           viewer_id: user_id,
           session_id: session_id,
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

  def handle_batch(:writer, messages, %BatchInfo{batch_key: session_id}, _context) do
    Vote.create_all(Enum.map(messages, fn message -> message.data end))

    {:ok, report} = Report.generate(%ListeningSession{id: session_id})
    PremiereEcoute.PubSub.broadcast("session:#{session_id}", {:session_summary, report.session_summary})

    messages
  end

  def handle_failed(messages, _context), do: messages
end
