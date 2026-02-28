defmodule PremiereEcoute.Presence do
  @moduledoc """
  Presence tracking.

  Manages real-time presence tracking for entities such as music players, allowing the system to monitor which entities have active connections into the system through a unique identifier.
  """

  use Phoenix.Presence,
    otp_app: :premiere_ecoute,
    pubsub_server: PremiereEcoute.PubSub

  @type role() :: :player | :overlay | :liveview

  def init(_opts) do
    {:ok, %{}}
  end

  def handle_metas(_topic, %{joins: _joins, leaves: _leaves} = _events, _presences, state) do
    # IO.inspect(events, label: topic)
    {:ok, state}
  end

  @doc "Registers process as present for key"
  @spec join(term(), role()) :: {:ok, binary()} | {:error, term()}
  def join(key, role \\ :unknown), do: __MODULE__.track(self(), topic(key), role, %{})

  @doc "Unregisters process presence for key"
  @spec unjoin(term(), role()) :: :ok
  def unjoin(key, role \\ :unknown), do: __MODULE__.untrack(self(), topic(key), role)

  @doc """
  Retrieves presence metadata for player.

  Returns list of presence metas for given player key.
  """
  @spec player(integer(), role()) :: list(map())
  def player(key, role) do
    topic(key)
    |> __MODULE__.list()
    |> Map.get(Atom.to_string(role), %{metas: []})
    |> Map.get(:metas)
  end

  defp topic(key), do: "presence:#{key}"
end
