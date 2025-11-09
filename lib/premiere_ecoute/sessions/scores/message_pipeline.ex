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

  @batch_timeout Application.compile_env(:premiere_ecoute, PremiereEcoute.Sessions)[:batch_timeout]

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [module: {PremiereEcouteCore.BroadwayProducer, []}, concurrency: 1],
      processors: [session: [concurrency: 1]],
      batchers: [writer: [concurrency: 1, batch_size: 5, batch_timeout: @batch_timeout]]
    )
  end

  def handle_message(:session, message, _) do
    case process(message.data) do
      {:ok, vote} -> message |> Message.put_data(vote) |> Message.put_batch_key(vote.session_id) |> Message.put_batcher(:writer)
      {:error, reason} -> message |> Message.failed(reason)
    end
  end

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

  def handle_failed(messages, _context), do: messages
end
