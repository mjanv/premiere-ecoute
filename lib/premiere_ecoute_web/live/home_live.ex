defmodule PremiereEcouteWeb.HomeLive do
  @moduledoc """
  Home page LiveView.
  """

  use PremiereEcouteWeb, :live_view

  import Ecto.Query, only: [from: 2]
  import PremiereEcouteWeb.HomeComponents

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Radio

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, %{assigns: %{current_scope: %{user: user}}} = socket) do
    last_sessions =
      ListeningSession.all(where: [user_id: user.id, status: :stopped, source: :album], order_by: [desc: :started_at], limit: 10)

    next_radio = Radio.next_in?(user.id)
    last_radios = PremiereEcoute.Radio.RadioTrack.all(where: [user_id: user.id], order_by: [desc: :started_at], limit: 10)

    upcoming_sessions =
      from(s in ListeningSession,
        where: s.user_id == ^user.id and s.status in [:active, :preparing],
        order_by: [fragment("CASE status WHEN 'active' THEN 0 ELSE 1 END"), asc: s.inserted_at]
      )
      |> Repo.all()
      |> ListeningSession.preload()

    socket
    |> assign(:current_user, User.preload(user))
    |> assign(:current_session, ListeningSession.current_session(user))
    |> assign(:listening_sessions, last_sessions)
    |> assign(next_radio: next_radio, last_radios: last_radios)
    |> assign(:upcoming_sessions, upcoming_sessions)
    |> then(fn socket -> {:noreply, socket} end)
  end
end
