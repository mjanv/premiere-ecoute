defmodule PremiereEcoute.Sessions.Chat.HashtagPipeline do
  @moduledoc """
  Broadway pipeline for caching hashtag chat messages.

  Processes MessageSent events from chat, extracts the first `#hashtag` found in the message, and
  caches it for display in the scrolling hashtag banner overlay. Not gated by an active session —
  any broadcaster's chat can feed the banner at any time.
  """

  use Broadway

  alias Broadway.Message
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions.Chat.HashtagMessage

  @doc """
  Starts the Broadway pipeline for hashtag message caching.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [module: {PremiereEcouteCore.BroadwayProducer, []}, concurrency: 1],
      processors: [default: [concurrency: 1]]
    )
  end

  @doc """
  Extracts and caches the first hashtag found in a chat message.
  """
  @spec handle_message(atom(), Message.t(), any()) :: Message.t()
  def handle_message(:default, message, _) do
    case message.data do
      %MessageSent{broadcaster_id: broadcaster_id, message: text} ->
        case HashtagMessage.parse(text) do
          {:ok, {hashtag, text}} -> HashtagMessage.put(broadcaster_id, hashtag, text)
          :error -> :ok
        end

      _ ->
        :ok
    end

    message
  end
end
