defmodule PremiereEcoute.Presence do
  @moduledoc """
  Presence tracking.

  Manages real-time presence tracking for entities such as music players, allowing the system to monitor which entities have active connections into the system through a unique identifier.
  """

  use Phoenix.Presence,
    otp_app: :premiere_ecoute,
    pubsub_server: PremiereEcoute.PubSub

  @topic "presence"

  @doc "Registers process as present for key"
  @spec join(term()) :: {:ok, binary()} | {:error, term()}
  def join(key), do: __MODULE__.track(self(), @topic, key, %{})

  @doc "Unregisters process presence for key"
  @spec unjoin(term()) :: :ok
  def unjoin(key), do: __MODULE__.untrack(self(), @topic, key)

  @doc """
  Retrieves presence metadata for player.

  Returns list of presence metas for given player key.
  """
  @spec player(integer()) :: list(map())
  def player(key) do
    @topic
    |> __MODULE__.list()
    |> Map.get(Integer.to_string(key), %{metas: []})
    |> Map.get(:metas)
  end
end
