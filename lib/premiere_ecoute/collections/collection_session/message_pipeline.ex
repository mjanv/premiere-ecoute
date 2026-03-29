defmodule PremiereEcoute.Collections.CollectionSession.MessagePipeline do
  @moduledoc """
  Broadway pipeline for processing collection session chat votes.

  Processes MessageSent events from Twitch chat. Interprets "1" and "2" as votes:
  - In viewer_vote mode: "1" = yes, "2" = no
  - In duel mode: "1" = track A, "2" = track B

  Increments in-memory vote counts in the cache and broadcasts live updates to the
  LiveView via PubSub. The streamer sees the final tally after the vote window closes
  and makes the final decision.
  """

  use Broadway

  require Logger

  alias Broadway.BatchInfo
  alias Broadway.Message
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcouteCore.Cache

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [module: {PremiereEcouteCore.BroadwayProducer, []}, concurrency: 1],
      processors: [session: [concurrency: 1]],
      batchers: [
        writer: [
          concurrency: 1,
          batch_size: 10,
          batch_timeout: Application.get_env(:premiere_ecoute, :broadway_batch_timeout_ms, 1_000)
        ]
      ]
    )
  end

  @doc false
  @spec handle_message(atom(), Message.t(), any()) :: Message.t()
  def handle_message(:session, message, _) do
    Logger.info("#{inspect(message)}")

    case process(message.data) do
      {:ok, vote} -> message |> Message.put_data(vote) |> Message.put_batch_key(vote.session_id) |> Message.put_batcher(:writer)
      {:error, reason} -> Message.failed(message, reason)
    end
  end

  @doc """
  Extracts a collection vote from a chat MessageSent event.

  Checks the :collections cache for an active vote window keyed by broadcaster_id.
  Returns the side (:a or :b) and session context if the message is a valid vote.
  """
  @spec process(MessageSent.t()) :: {:ok, map()} | {:error, term()}
  def process(%MessageSent{broadcaster_id: broadcaster_id, user_id: user_id, message: message}) do
    with {:ok, %{active_track_id: track_id, session_id: session_id}} when not is_nil(track_id) <-
           Cache.get(:collections, broadcaster_id),
         {:ok, side} <- parse_side(message) do
      {:ok,
       %{
         broadcaster_id: broadcaster_id,
         session_id: session_id,
         track_id: track_id,
         user_id: user_id,
         side: side
       }}
    else
      _ -> {:error, :not_a_collection_vote}
    end
  end

  @doc false
  @spec handle_batch(atom(), [Message.t()], BatchInfo.t(), any()) :: [Message.t()]
  def handle_batch(:writer, messages, %BatchInfo{batch_key: session_id}, _context) do
    broadcaster_id = hd(messages).data.broadcaster_id

    with {:ok, cached} <- Cache.get(:collections, broadcaster_id) do
      {count_a, count_b} =
        Enum.reduce(messages, {0, 0}, fn msg, {a, b} ->
          case msg.data.side do
            :a -> {a + 1, b}
            :b -> {a, b + 1}
          end
        end)

      updated =
        cached
        |> Map.update(:votes_a, count_a, &(&1 + count_a))
        |> Map.update(:votes_b, count_b, &(&1 + count_b))

      Cache.put(:collections, broadcaster_id, updated)

      PremiereEcoute.PubSub.broadcast(
        "collection:#{session_id}",
        {:vote_update, %{votes_a: updated.votes_a, votes_b: updated.votes_b}}
      )
    end

    messages
  end

  @doc false
  @spec handle_failed([Message.t()], any()) :: [Message.t()]
  def handle_failed(messages, _context), do: messages

  defp parse_side(message) do
    trimmed = String.trim(message)

    cond do
      trimmed == "1" -> {:ok, :a}
      trimmed == "2" -> {:ok, :b}
      String.ends_with?(trimmed, " 1") -> {:ok, :a}
      String.ends_with?(trimmed, " 2") -> {:ok, :b}
      true -> {:error, :invalid_vote}
    end
  end
end
