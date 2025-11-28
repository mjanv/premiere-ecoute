defmodule PremiereEcoute.Apis.SpotifyPlayer do
  @moduledoc """
  Spotify playback state monitoring GenServer.

  Polls the Spotify API every second to track playback state changes and broadcasts events for play/pause, track changes, and playback progress to user-specific PubSub channels.
  """

  use GenServer, restart: :transient

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Presence

  @registry PremiereEcoute.Apis.PlayerRegistry
  @poll_interval 1_000

  @doc """
  Starts the Spotify player monitoring GenServer.

  Launches a GenServer registered via Registry to monitor Spotify playback state for a specific user.
  """
  @spec start_link(integer()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: {:via, Registry, {@registry, args}})
  end

  @doc false
  @spec init(integer()) :: {:ok, map()} | {:stop, {:error, term()}}
  @impl true
  def init(args) do
    Process.send_after(self(), :poll, @poll_interval)
    scope = Scope.for_user(User.get(args))

    with {:ok, phx_ref} <- Presence.join(scope.user.id),
         {:ok, state} <- Apis.spotify().get_playback_state(scope, %{}) do
      {:ok, %{phx_ref: phx_ref, scope: scope, state: state}}
    else
      {:error, reason} ->
        publish(scope, {:error, reason}, %{})
        {:stop, {:error, reason}}
    end
  end

  @impl true
  def handle_info(:poll, %{scope: scope, state: old_state} = data) do
    with _ <- Process.send_after(self(), :poll, @poll_interval),
         scope <- Accounts.maybe_renew_token(%{assigns: %{current_scope: scope}}, :spotify),
         {:ok, new_state} <- Apis.spotify().get_playback_state(scope, old_state),
         {:ok, state, events} <- handle(old_state, new_state),
         :ok <- Enum.each(events, fn event -> publish(scope, event, state) end) do
      if length(PremiereEcoute.Presence.player(scope.user.id)) > 1 do
        {:noreply, %{scope: scope, state: state}}
      else
        {:stop, :normal, %{scope: scope, state: state}}
      end
    else
      {:error, reason} -> {:stop, {:error, reason}, data}
    end
  end

  @impl true
  def terminate(reason, %{scope: scope, state: state}) do
    case reason do
      :normal ->
        :ok

      reason ->
        Logger.warning("Stop Spotify player due to: #{inspect(reason)}")
        publish(scope, reason, state)
    end

    :ok
  end

  defp publish(scope, event, state) do
    PremiereEcoute.PubSub.broadcast("playback:#{scope.user.id}", {:player, event, state})
  end

  @doc """
  Calculates playback progress as a percentage.

  Returns playback progress percentage (0-100) from current position and total track duration in playback state.
  """
  @spec progress(map()) :: integer()
  def progress(state), do: trunc(100 * (state["progress_ms"] / (state["item"]["duration_ms"] + 1)))

  @doc """
  Detects playback state changes and generates events.

  Compares old and new playback states to identify transitions (play/pause, track changes, progress updates) and returns the new state with corresponding event list.
  """
  @spec handle(map(), map()) :: {:ok, map(), list()}
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
      {98, 99} -> {:ok, new_state, [:end_track]}
      {a, b} when abs(b - a) > 5 -> {:ok, new_state, [{:skip, b}]}
      {a, b} when b > a -> {:ok, new_state, [{:percent, b}]}
      _ -> {:ok, new_state, []}
    end
  end
end
