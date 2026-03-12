defmodule PremiereEcouteWeb.HomeLive do
  @moduledoc """
  Home page LiveView.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.HomeComponents

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Radio
  alias PremiereEcoute.Sessions

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(30_000, self(), :refresh)
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, %{assigns: %{current_scope: %{user: user}}} = socket) do
    socket
    |> assign(:current_user, User.preload(user))
    |> assign(
      current_session: Sessions.current_session(user),
      listening_sessions: Sessions.stopped_sessions(user),
      upcoming_sessions: Sessions.upcoming_sessions(user)
    )
    |> assign(
      next_radio: Radio.next_in?(user.id),
      last_radios: Radio.last_tracks(user.id)
    )
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info(:refresh, %{assigns: %{current_scope: %{user: user}}} = socket) do
    {:noreply, assign(socket, next_radio: Radio.next_in?(user.id), last_radios: Radio.last_tracks(user.id))}
  end

  @impl true
  def handle_event("start_radio", _params, %{assigns: %{current_scope: %{user: user}}} = socket) do
    case Radio.start_radio(user) do
      {:ok, _} -> {:noreply, assign(socket, next_radio: Radio.next_in?(user.id))}
      _ -> {:noreply, put_flash(socket, :error, gettext("Failed to start radio"))}
    end
  end

  @impl true
  def handle_event("stop_radio", _params, %{assigns: %{current_scope: %{user: user}}} = socket) do
    case Radio.stop_radio(user) do
      {:ok, 1} -> {:noreply, assign(socket, next_radio: Radio.next_in?(user.id))}
      _ -> {:noreply, put_flash(socket, :error, gettext("Failed to stop radio"))}
    end
  end
end
