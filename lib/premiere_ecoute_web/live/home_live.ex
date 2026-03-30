defmodule PremiereEcouteWeb.HomeLive do
  @moduledoc """
  Home page LiveView.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Home.Components

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Radio
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Wantlists

  embed_templates "home/*"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(30_000, self(), :refresh)
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, %{assigns: %{current_scope: %{user: %{role: :viewer} = user}}} = socket) do
    current_user = User.preload(user)
    sessions_by_user = Sessions.stopped_sessions_from_followed(user) |> Enum.group_by(& &1.user_id)
    upcoming_sessions = Sessions.upcoming_sessions_from_followed(user)

    # AIDEV-NOTE: preserves follow order from current_user.channels
    sessions_per_streamer =
      current_user.channels
      |> Enum.map(fn streamer -> {streamer, Map.get(sessions_by_user, streamer.id, [])} end)

    my_sessions =
      case current_user.twitch do
        %{user_id: twitch_id} -> Sessions.viewer_voted_sessions(twitch_id)
        _ -> []
      end

    # AIDEV-NOTE: collect album ids in wantlist for the viewer to mark them visually
    wantlisted_album_ids = build_wantlisted_album_ids(user.id, sessions_by_user, my_sessions)

    socket
    |> assign(:current_user, current_user)
    |> assign(:sessions_per_streamer, sessions_per_streamer)
    |> assign(:upcoming_sessions, upcoming_sessions)
    |> assign(:my_sessions, my_sessions)
    |> assign(:wantlisted_album_ids, wantlisted_album_ids)
    |> then(fn socket -> {:noreply, socket} end)
  end

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

  @impl true
  def handle_event("add_album_to_wantlist", %{"album-id" => album_id}, socket) do
    user = socket.assigns.current_scope.user

    case Wantlists.add_item(user.id, :album, String.to_integer(album_id)) do
      {:ok, _} ->
        wantlisted_album_ids = MapSet.put(socket.assigns[:wantlisted_album_ids] || MapSet.new(), String.to_integer(album_id))
        {:noreply, assign(socket, :wantlisted_album_ids, wantlisted_album_ids) |> put_flash(:info, gettext("Added to wantlist"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not add to wantlist"))}
    end
  end

  # AIDEV-NOTE: collects album ids that are already in the viewer's wantlist for visual feedback
  defp build_wantlisted_album_ids(user_id, sessions_by_user, my_sessions) do
    all_album_ids =
      sessions_by_user
      |> Map.values()
      |> List.flatten()
      |> Enum.concat(my_sessions)
      |> Enum.map(& &1.album_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    all_album_ids
    |> Enum.filter(&Wantlists.in_wantlist?(user_id, :album, &1))
    |> MapSet.new()
  end

  # AIDEV-NOTE: render/1 dispatches to separate templates based on user role
  @impl true
  def render(%{current_user: %{role: :viewer}} = assigns) do
    viewer(assigns)
  end

  def render(assigns) do
    streamer(assigns)
  end
end
