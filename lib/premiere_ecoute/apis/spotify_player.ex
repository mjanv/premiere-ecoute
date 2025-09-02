defmodule PremiereEcoute.Apis.SpotifyPlayer do
  @moduledoc false

  use GenServer, restart: :temporary

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Presence

  @registry PremiereEcoute.Apis.PlayerRegistry
  @poll_interval 1_000

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: {:via, Registry, {@registry, args}})
  end

  @impl true
  def init(args) do
    Logger.info("Start Spotify player with args: #{inspect(args)}")

    Process.send_after(self(), :poll, @poll_interval)
    scope = Scope.for_user(User.get(args))
    {:ok, phx_ref} = Presence.join(scope.user.id)

    state =
      case Apis.spotify().get_playback_state(scope, %{}) do
        {:ok, state} -> state
        {:error, _} -> %{}
      end

    {:ok, %{scope: scope, phx_ref: phx_ref, state: state}}
  end

  @impl true
  def handle_info(:poll, %{scope: scope, state: old_state}) do
    Process.send_after(self(), :poll, @poll_interval)

    with {:ok, new_state} <- Apis.spotify().get_playback_state(scope, old_state),
         {:ok, state, events} <- handle(old_state, new_state),
         :ok <- Enum.each(events, fn event -> publish(scope, event, state) end) do
      if length(PremiereEcoute.Presence.player(scope.user.id)) > 1 do
        {:noreply, %{scope: scope, state: state}}
      else
        {:stop, :normal, %{scope: scope, state: state}}
      end
    end
  end

  @impl true
  def terminate(reason, _state) do
    Logger.info("Stop Spotify player due to: #{inspect(reason)}")
    :ok
  end

  defp publish(scope, event, state) do
    PremiereEcoute.PubSub.broadcast("playback:#{scope.user.id}", {:player, event, state})
  end

  def progress(state), do: trunc(100 * (state["progress_ms"] / (state["item"]["duration_ms"] + 1)))

  def handle(old_state, new_state) when old_state == %{}, do: {:ok, new_state, []}
  def handle(%{"device" => nil}, new_state), do: {:ok, new_state, []}
  def handle(_old_state, %{"device" => nil} = new_state), do: {:ok, new_state, [:no_device]}
  def handle(%{"is_playing" => false}, %{"is_playing" => true} = state), do: {:ok, state, [:start]}
  def handle(%{"is_playing" => true}, %{"is_playing" => false} = state), do: {:ok, state, [:stop]}

  def handle(%{"item" => %{"uri" => uri1}}, %{"item" => %{"uri" => uri2}} = state) when uri1 != uri2,
    do: {:ok, state, [:new_track]}

  def handle(old_state, new_state) do
    case {progress(old_state), progress(new_state)} do
      {0, 1} -> {:ok, new_state, [:start_track]}
      {97, 98} -> {:ok, new_state, [:end_track]}
      {a, b} when abs(b - a) > 5 -> {:ok, new_state, [:skip]}
      {a, b} when b > a -> {:ok, new_state, [b]}
      _ -> {:ok, new_state, []}
    end
  end
end
