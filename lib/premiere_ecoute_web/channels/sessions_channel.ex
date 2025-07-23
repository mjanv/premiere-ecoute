defmodule PremiereEcouteWeb.SessionsChannel do
  @moduledoc false

  use PremiereEcouteWeb, :channel

  alias PremiereEcoute.Sessions.ListeningSession

  @impl true
  def join("sessions:lobby", _payload, socket) do
    {:ok, socket}
  end

  def join(_, _, socket), do: {:ok, socket}

  @impl true
  def handle_in("get_sessions", _payload, socket) do
    sessions = ListeningSession.all(where: [status: :active])
    sessions = Enum.map(sessions, fn session -> Jason.encode!(session) end)
    {:reply, {:ok, %{"data" => sessions}}, socket}
  end
end
