defmodule PremiereEcoute.Presence do
  @moduledoc false

  use Phoenix.Presence,
    otp_app: :premiere_ecoute,
    pubsub_server: PremiereEcoute.PubSub

  @topic "players"

  def join(key), do: __MODULE__.track(self(), @topic, key, %{})
  def unjoin(key), do: __MODULE__.untrack(self(), @topic, key)

  def player(key) do
    @topic
    |> __MODULE__.list()
    |> Map.get(Integer.to_string(key), %{metas: []})
    |> Map.get(:metas)
  end
end
