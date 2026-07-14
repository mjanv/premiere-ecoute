defmodule PremiereEcouteWeb.HomeLive do
  @moduledoc """
  Home page LiveView.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Home.Components

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Playlists
  alias PremiereEcoute.Podcasts
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

    # Preserves follow order from current_user.channels.
    sessions_per_streamer =
      current_user.channels
      |> Enum.map(fn streamer -> {streamer, Map.get(sessions_by_user, streamer.id, [])} end)

    {my_sessions, missed_session_ids} =
      case current_user.twitch do
        %{user_id: twitch_id} ->
          missed_ids =
            user
            |> Sessions.missed_sessions_from_followed(twitch_id)
            |> MapSet.new(& &1.id)

          {Sessions.viewer_voted_sessions(twitch_id), missed_ids}

        _ ->
          {[], MapSet.new()}
      end

    wantlisted_album_ids = build_wantlisted_album_ids(user.id, sessions_by_user, my_sessions)

    streamer_ids = Enum.map(current_user.channels, & &1.id)
    open_playlists = Playlists.list_open_for_subscriptions(streamer_ids)
    playlists_by_streamer = Enum.group_by(open_playlists, & &1.user_id)

    # Preserves follow order from current_user.channels, same pattern as sessions_per_streamer.
    open_playlists_per_streamer =
      current_user.channels
      |> Enum.map(fn streamer -> {streamer, Map.get(playlists_by_streamer, streamer.id, [])} end)
      |> Enum.reject(fn {_streamer, playlists} -> playlists == [] end)

    subscribed_playlist_ids = Playlists.subscribed_playlist_ids(user, open_playlists)

    # Published podcasts of followed streamers, grouped by streamer id — drives the
    # per-streamer "Podcasts" section in the home page.
    podcasts_per_streamer = Podcasts.published_shows_by_users(streamer_ids)

    socket
    |> assign(:current_user, current_user)
    |> assign(:sessions_per_streamer, sessions_per_streamer)
    |> assign(:upcoming_sessions, upcoming_sessions)
    |> assign(:my_sessions, my_sessions)
    |> assign(:missed_session_ids, missed_session_ids)
    |> assign(:wantlisted_album_ids, wantlisted_album_ids)
    |> assign(:open_playlists_per_streamer, open_playlists_per_streamer)
    |> assign(:subscribed_playlist_ids, subscribed_playlist_ids)
    |> assign(:podcasts_per_streamer, podcasts_per_streamer)
    |> assign(:subscription_modal, nil)
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
  def handle_event("open_subscription_modal", %{"playlist-id" => playlist_id}, socket) do
    playlist =
      Enum.find_value(socket.assigns.open_playlists_per_streamer, fn {_streamer, playlists} ->
        Enum.find(playlists, &(&1.id == String.to_integer(playlist_id)))
      end)

    case playlist do
      nil ->
        {:noreply, socket}

      playlist ->
        viewer = socket.assigns.current_scope.user

        channels = %{
          email: Playlists.subscribed?(playlist, viewer, :email),
          notification: Playlists.subscribed?(playlist, viewer, :notification)
        }

        {:noreply, assign(socket, :subscription_modal, %{playlist: playlist, channels: channels})}
    end
  end

  @impl true
  def handle_event("close_subscription_modal", _params, socket) do
    {:noreply, assign(socket, :subscription_modal, nil)}
  end

  @impl true
  def handle_event("unsubscribe_all", _params, socket) do
    %{playlist: playlist, channels: channels} = socket.assigns.subscription_modal
    viewer = socket.assigns.current_scope.user

    results =
      channels
      |> Enum.filter(fn {_ch, subscribed} -> subscribed end)
      |> Enum.map(fn {ch, _} -> Playlists.unsubscribe(playlist, viewer, ch) end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      subscribed_playlist_ids = MapSet.delete(socket.assigns.subscribed_playlist_ids, playlist.id)
      new_channels = Map.new(channels, fn {ch, _} -> {ch, false} end)

      {:noreply,
       socket
       |> assign(:subscription_modal, %{playlist: playlist, channels: new_channels})
       |> assign(:subscribed_playlist_ids, subscribed_playlist_ids)}
    else
      {:noreply, put_flash(socket, :error, gettext("Something went wrong. Please try again."))}
    end
  end

  @impl true
  def handle_event("subscribe_all", _params, socket) do
    %{playlist: playlist, channels: channels} = socket.assigns.subscription_modal
    viewer = socket.assigns.current_scope.user

    results =
      channels
      |> Enum.reject(fn {_ch, subscribed} -> subscribed end)
      |> Enum.map(fn {ch, _} -> Playlists.subscribe(playlist, viewer, ch) end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      subscribed_playlist_ids = MapSet.put(socket.assigns.subscribed_playlist_ids, playlist.id)
      new_channels = Map.new(channels, fn {ch, _} -> {ch, true} end)

      {:noreply,
       socket
       |> assign(:subscription_modal, %{playlist: playlist, channels: new_channels})
       |> assign(:subscribed_playlist_ids, subscribed_playlist_ids)}
    else
      {:noreply, put_flash(socket, :error, gettext("Something went wrong. Please try again."))}
    end
  end

  @impl true
  def handle_event("toggle_subscription", %{"channel" => channel}, socket)
      when channel in ["email", "notification"] do
    %{playlist: playlist, channels: channels} = socket.assigns.subscription_modal
    viewer = socket.assigns.current_scope.user
    ch = String.to_existing_atom(channel)
    currently_subscribed = Map.get(channels, ch, false)

    result =
      if currently_subscribed do
        Playlists.unsubscribe(playlist, viewer, ch)
      else
        Playlists.subscribe(playlist, viewer, ch)
      end

    case result do
      {:ok, _} ->
        new_channels = Map.put(channels, ch, !currently_subscribed)
        any_subscribed = Enum.any?(new_channels, fn {_ch, v} -> v end)

        subscribed_playlist_ids =
          if any_subscribed do
            MapSet.put(socket.assigns.subscribed_playlist_ids, playlist.id)
          else
            MapSet.delete(socket.assigns.subscribed_playlist_ids, playlist.id)
          end

        {:noreply,
         socket
         |> assign(:subscription_modal, %{playlist: playlist, channels: new_channels})
         |> assign(:subscribed_playlist_ids, subscribed_playlist_ids)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Something went wrong. Please try again."))}
    end
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

  @impl true
  def render(%{current_user: %{role: :viewer}} = assigns) do
    viewer(assigns)
  end

  def render(assigns) do
    streamer(assigns)
  end
end
