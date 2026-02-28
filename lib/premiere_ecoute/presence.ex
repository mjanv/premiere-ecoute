defmodule PremiereEcoute.Presence do
  @moduledoc """
  Presence tracking.

  Manages real-time presence tracking for entities such as music players, allowing the system to monitor which entities have active connections into the system through a unique identifier.
  """

  use Phoenix.Presence,
    otp_app: :premiere_ecoute,
    pubsub_server: PremiereEcoute.PubSub

  @type role() :: :player | :overlay | :unknown

  def init(_opts) do
    {:ok, %{}}
  end

  def handle_metas("presence:" <> user_id, %{leaves: leaves}, presences, state) do
    overlay_left = Map.has_key?(leaves, "overlay")

    overlay_count =
      presences
      |> Map.get("overlay", [])
      |> length()

    # AIDEV-NOTE: only broadcast when a leave caused the last overlay to disconnect
    if overlay_left and overlay_count == 0 do
      PremiereEcoute.PubSub.broadcast("player:#{user_id}", :no_overlay)
    end

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
