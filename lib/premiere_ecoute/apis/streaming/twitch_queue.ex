defmodule PremiereEcoute.Apis.Streaming.TwitchQueue do
  @moduledoc """
  Twitch message queue

  Manages a circuit-breaker protected message queue for sending Twitch chat messages with automatic rate limiting. When rate limits are exceeded (1 message per second per broadcaster, 20 messages per 30 seconds globally), the circuit opens and queues messages until the limit window expires, then automatically retries. Requires a bot account to exist in the database at startup; if no bot is found, the GenServer returns `:ignore` and the application must be redeployed after creating the bot account.
  """

  use GenServer

  alias PremiereEcoute.Accounts.Bot
  alias PremiereEcoute.Apis.RateLimit
  alias PremiereEcoute.Apis.Streaming.TwitchApi.Chat

  @doc """
  Starts the Twitch message queue GenServer.

  Links a GenServer process for managing Twitch chat message queueing with circuit breaker protection.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc false
  @spec init(term()) :: {:ok, map()} | :ignore
  def init(_args) do
    case Bot.get() do
      {:ok, bot} -> {:ok, %{circuit: :closed, bot: bot, timer: nil, messages: []}}
      {:error, _} -> :ignore
    end
  end

  @doc """
  Pushes message(s) to the Twitch queue for sending.

  Queues messages for delivery through circuit-breaker protected rate-limited sending to Twitch chat.
  """
  @spec push([{atom(), map()}] | {atom(), map()}) :: :ok
  def push(messages) when is_list(messages), do: Enum.each(messages, &push/1)
  def push({action, message}), do: GenServer.cast(__MODULE__, {action, message})

  # Handlers
  @spec handle_cast({atom(), map()}, map()) :: {:noreply, map()}
  def handle_cast({action, message}, %{circuit: :closed, bot: bot, messages: messages} = state) do
    {:ok, bot} = maybe_refresh_bot(bot)

    {circuit, new_timer, messages} =
      case try_send(bot, action, message) do
        {:ok, _message} -> {:closed, nil, messages}
        {:error, timer} -> {:open, timer, messages ++ [{action, message}]}
      end

    {:noreply, %{state | bot: bot, circuit: circuit, timer: new_timer, messages: messages}}
  end

  def handle_cast({action, message}, %{circuit: :open, messages: messages} = state) do
    {:noreply, %{state | messages: messages ++ [{action, message}]}}
  end

  @spec handle_info(atom(), map()) :: {:noreply, map()}
  def handle_info(:retry, %{messages: []} = state) do
    {:noreply, %{state | circuit: :closed}}
  end

  def handle_info(:retry, %{circuit: :open, bot: bot, messages: [{action, message} | messages]} = state) do
    {:ok, bot} = maybe_refresh_bot(bot)

    {timer, messages} =
      case try_send(bot, action, message) do
        {:ok, _message} ->
          Process.send_after(self(), :retry, 0)
          {nil, messages}

        {:error, timer} ->
          {timer, [{action, message}] ++ messages}
      end

    {:noreply, %{state | bot: bot, timer: timer, messages: messages}}
  end

  # Private
  defp maybe_refresh_bot(%{twitch: %{expires_at: expires_at}} = bot) do
    if token_expired?(expires_at), do: Bot.get(), else: {:ok, bot}
  end

  defp token_expired?(nil), do: false
  defp token_expired?(at), do: DateTime.compare(DateTime.utc_now(), DateTime.add(at, -300, :second)) == :gt

  defp try_send(bot, action, message) do
    message
    |> hit([
      {"broadcaster:#{message.user_id}", :timer.seconds(1), 1},
      {"twitch", :timer.seconds(30), 20}
    ])
    |> case do
      {:allow, message} ->
        apply(Chat, action, [bot, message])
        {:ok, message}

      {:deny, retry_after} ->
        {:error, Process.send_after(self(), :retry, retry_after)}
    end
  end

  defp hit(message, rates) do
    rates
    |> Enum.map(fn {k, t, h} -> RateLimit.hit(k, t, h) end)
    |> Enum.filter(fn {result, _} -> result == :deny end)
    |> case do
      [] -> {:allow, message}
      rates -> {:deny, rates |> Enum.map(fn {_, retry_after} -> retry_after end) |> Enum.max()}
    end
  end
end
