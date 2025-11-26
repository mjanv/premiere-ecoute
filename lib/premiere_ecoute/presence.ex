defmodule PremiereEcoute.Presence do
  @moduledoc """
  Presence tracking.

  Manages real-time presence tracking for entities such as music players, allowing the system to monitor which entities have active connections into the system through a unique identifier.
  """

  use Phoenix.Presence,
    otp_app: :premiere_ecoute,
    pubsub_server: PremiereEcoute.PubSub

  @topic "presence"

  def join(key), do: __MODULE__.track(self(), @topic, key, %{})
  def unjoin(key), do: __MODULE__.untrack(self(), @topic, key)

  def player(key) do
    @topic
    |> __MODULE__.list()
    |> Map.get(Integer.to_string(key), %{metas: []})
    |> Map.get(:metas)
  end
end
