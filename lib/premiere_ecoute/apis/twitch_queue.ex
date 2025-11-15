defmodule PremiereEcoute.Apis.TwitchQueue do
  @moduledoc """
  Twitch message queue

  If the bot account user is not present at initialization, the bot will not be started. If the bot is created afterwards, the application must be redeployed to enable the message queue.
  """

  use GenServer

  alias PremiereEcoute.Accounts.Bot
  alias PremiereEcoute.Apis.RateLimit
  alias PremiereEcoute.Apis.TwitchApi.Chat

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    # TODO: Write more specific unit tests about Twitch Queue
    case Bot.get() do
      {:ok, bot} -> {:ok, %{circuit: :closed, bot: bot, timer: nil, messages: []}}
      {:error, _} -> :ignore
    end
  end

  def handle_cast({action, message}, %{circuit: :closed, bot: bot, messages: messages} = state) do
    {circuit, new_timer, messages} =
      case try_send(bot, action, message) do
        {:ok, _message} -> {:closed, nil, messages}
        {:error, timer} -> {:open, timer, messages ++ [{action, message}]}
      end

    {:noreply, %{state | circuit: circuit, timer: new_timer, messages: messages}}
  end

  def handle_cast({action, message}, %{circuit: :open, messages: messages} = state) do
    {:noreply, %{state | messages: messages ++ [{action, message}]}}
  end

  def handle_info(:retry, %{messages: []} = state) do
    {:noreply, %{state | circuit: :closed}}
  end

  def handle_info(:retry, %{circuit: :open, bot: bot, messages: [{action, message} | messages]} = state) do
    {timer, messages} =
      case try_send(bot, action, message) do
        {:ok, _message} ->
          Process.send_after(self(), :retry, 0)
          {nil, messages}

        {:error, timer} ->
          {timer, [message] ++ messages}
      end

    {:noreply, %{state | timer: timer, messages: messages}}
  end

  def try_send(bot, action, message) do
    message
    |> hit([
      {"twitch", :timer.seconds(5), 1},
      {"broadcaster:#{message.user_id}", :timer.seconds(5), 1}
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

  def push(messages) when is_list(messages), do: Enum.each(messages, &push/1)
  def push({action, message}), do: GenServer.cast(__MODULE__, {action, message})
end
