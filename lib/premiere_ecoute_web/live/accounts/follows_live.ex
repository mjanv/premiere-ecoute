defmodule PremiereEcouteWeb.Accounts.FollowsLive do
  @moduledoc """
  LiveView for managing user follows.

  Allows authenticated users to view their current follows, unfollow streamers,
  and discover new streamers to follow through an interactive interface.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = Accounts.preload_user(socket.assigns.current_scope.user)

    socket
    |> assign(:current_user, user)
    |> assign(:show_follow_modal, false)
    |> assign(:show_unfollow_modal, false)
    |> assign(:to_unfollow, nil)
    |> assign(:streamers, Accounts.discover_follows(user))
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, :current_path, URI.parse(url).path || "/")}
  end

  @impl true
  def handle_event("show_unfollow_modal", %{"streamer_id" => streamer_id}, socket) do
    streamer = Enum.find(socket.assigns.current_user.channels, &(&1.id == String.to_integer(streamer_id)))

    socket
    |> assign(:show_unfollow_modal, true)
    |> assign(:to_unfollow, streamer)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("hide_unfollow_modal", _params, socket) do
    socket
    |> assign(:show_unfollow_modal, false)
    |> assign(:to_unfollow, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("show_follow_modal", _params, socket) do
    socket
    |> assign(:show_follow_modal, true)
    |> assign(:streamers, Accounts.discover_follows(socket.assigns.current_user))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("hide_follow_modal", _params, socket) do
    socket
    |> assign(:show_follow_modal, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("modal_content_click", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("follow_streamer", %{"streamer_id" => id}, %{assigns: %{streamers: streamers}} = socket) do
    case Enum.find(streamers, &(&1.id == String.to_integer(id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Streamer not found")}

      streamer ->
        case Accounts.follow_streamer(socket.assigns.current_scope, streamer) do
          {:ok, _follow} ->
            user = Accounts.preload_user(socket.assigns.current_scope.user)

            socket
            |> assign(:current_user, user)
            |> assign(:show_follow_modal, false)
            |> assign(:streamers, Accounts.discover_follows(socket.assigns.current_user))
            |> put_flash(:info, "Successfully followed #{streamer.email}")
            |> then(fn socket -> {:noreply, socket} end)

          {:error, _changeset} ->
            socket
            |> put_flash(:error, "Failed to follow streamer")
            |> then(fn socket -> {:noreply, socket} end)
        end
    end
  end

  @impl true
  def handle_event("unfollow_streamer", _params, socket) do
    case socket.assigns.to_unfollow do
      nil ->
        {:noreply, put_flash(socket, :error, "No streamer selected")}

      streamer ->
        case Accounts.unfollow(socket.assigns.current_user, streamer) do
          {:ok, _follow} ->
            user = Accounts.preload_user(socket.assigns.current_scope.user)

            socket
            |> assign(:current_user, user)
            |> assign(:show_unfollow_modal, false)
            |> assign(:to_unfollow, nil)
            |> assign(:streamers, Accounts.discover_follows(user))
            |> put_flash(:info, "Successfully unfollowed #{streamer.email}")
            |> then(fn socket -> {:noreply, socket} end)

          {:error, _changeset} ->
            socket
            |> assign(:show_unfollow_modal, false)
            |> assign(:to_unfollow, nil)
            |> put_flash(:error, "Failed to unfollow streamer")
            |> then(fn socket -> {:noreply, socket} end)
        end
    end
  end
end
