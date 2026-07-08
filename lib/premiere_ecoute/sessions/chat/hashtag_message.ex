defmodule PremiereEcoute.Sessions.Chat.HashtagMessage do
  @moduledoc """
  Hashtag chat messages cache.

  Extracts the first `#hashtag` from chat messages and caches them in memory (TTL-bound, no session
  gating) so a scrolling banner overlay can display live audience reactions across listening and
  collection sessions.
  """

  alias PremiereEcouteCore.Cache

  @ttl :timer.minutes(2)
  @hashtag_regex ~r/#(\w+)/u

  @doc "Returns the cache TTL (ms) applied to hashtag messages."
  @spec ttl() :: pos_integer()
  def ttl, do: @ttl

  @doc """
  Extracts the first hashtag from a chat message.

  Returns `{:ok, {hashtag, message}}` if a `#hashtag` is found, `:error` otherwise.
  """
  @spec parse(String.t()) :: {:ok, {String.t(), String.t()}} | :error
  def parse(message) do
    case Regex.run(@hashtag_regex, message) do
      [_, hashtag] -> {:ok, {"#" <> hashtag, message}}
      nil -> :error
    end
  end

  @doc """
  Caches a hashtag message for a broadcaster, with a fixed TTL, and broadcasts it for live overlays.
  """
  @spec put(String.t(), String.t(), String.t()) :: :ok
  def put(broadcaster_id, hashtag, message) do
    entry = %{broadcaster_id: broadcaster_id, hashtag: hashtag, message: message, inserted_at: DateTime.utc_now()}
    key = {broadcaster_id, System.unique_integer([:monotonic, :positive])}

    Cache.put(:hashtags, key, entry, ttl: @ttl)
    PremiereEcoute.PubSub.broadcast("hashtags:#{broadcaster_id}", {:hashtag_message, entry})

    :ok
  end

  @doc """
  Lists all non-expired hashtag messages cached for a broadcaster, oldest first.
  """
  @spec list(String.t()) :: [map()]
  def list(broadcaster_id) do
    :hashtags
    |> Cachex.stream!(Cachex.Query.build(output: :value))
    |> Enum.filter(&(&1.broadcaster_id == broadcaster_id))
    |> Enum.sort_by(& &1.inserted_at, DateTime)
  end
end
