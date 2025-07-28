defmodule PremiereEcouteWeb.Accounts.FollowsLive do
  @moduledoc """
  LiveView for managing user follows.

  Allows authenticated users to view their current follows, unfollow streamers,
  and discover new streamers to follow through an interactive interface.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

    if current_user do
      # AIDEV-NOTE: Load user with follows preloaded to display current follows
      user_with_follows =
        current_user
        |> Repo.preload(follows: :streamer, channels: [])

      socket =
        socket
        |> assign(:current_user, user_with_follows)
        |> assign(:follows, user_with_follows.channels)
        |> assign(:show_unfollow_modal, false)
        |> assign(:unfollow_target, nil)
        |> assign(:show_follow_modal, false)
        |> assign(:available_streamers, [])
        |> load_available_streamers()

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, :current_path, URI.parse(url).path || "/")}
  end

  @impl true
  def handle_event("show_unfollow_modal", %{"streamer_id" => streamer_id}, socket) do
    streamer = Enum.find(socket.assigns.follows, &(&1.id == String.to_integer(streamer_id)))

    socket =
      socket
      |> assign(:show_unfollow_modal, true)
      |> assign(:unfollow_target, streamer)

    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_unfollow_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_unfollow_modal, false)
      |> assign(:unfollow_target, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_unfollow", _params, socket) do
    case socket.assigns.unfollow_target do
      nil ->
        {:noreply, put_flash(socket, :error, "No streamer selected")}

      streamer ->
        case Accounts.unfollow(socket.assigns.current_user, streamer) do
          {:ok, _follow} ->
            # AIDEV-NOTE: Refresh follows after successful unfollow
            user_with_follows =
              socket.assigns.current_user
              |> Repo.preload([follows: :streamer, channels: []], force: true)

            socket =
              socket
              |> assign(:current_user, user_with_follows)
              |> assign(:follows, user_with_follows.channels)
              |> assign(:show_unfollow_modal, false)
              |> assign(:unfollow_target, nil)
              |> load_available_streamers()
              |> put_flash(:info, "Successfully unfollowed #{streamer.email}")

            {:noreply, socket}

          {:error, _changeset} ->
            socket =
              socket
              |> assign(:show_unfollow_modal, false)
              |> assign(:unfollow_target, nil)
              |> put_flash(:error, "Failed to unfollow streamer")

            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("show_follow_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_follow_modal, true)
      |> load_available_streamers()

    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_follow_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_follow_modal, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("modal_content_click", _params, socket) do
    # AIDEV-NOTE: Prevent modal from closing when clicking inside modal content
    {:noreply, socket}
  end

  @impl true
  def handle_event("follow_streamer", %{"streamer_id" => streamer_id}, socket) do
    streamer = Enum.find(socket.assigns.available_streamers, &(&1.id == String.to_integer(streamer_id)))

    case streamer do
      nil ->
        {:noreply, put_flash(socket, :error, "Streamer not found")}

      streamer ->
        case Accounts.follow(socket.assigns.current_user, streamer) do
          {:ok, _follow} ->
            # AIDEV-NOTE: Refresh follows after successful follow
            user_with_follows =
              socket.assigns.current_user
              |> Repo.preload([follows: :streamer, channels: []], force: true)

            socket =
              socket
              |> assign(:current_user, user_with_follows)
              |> assign(:follows, user_with_follows.channels)
              |> assign(:show_follow_modal, false)
              |> load_available_streamers()
              |> put_flash(:info, "Successfully followed #{streamer.email}")

            {:noreply, socket}

          {:error, _changeset} ->
            socket =
              socket
              |> put_flash(:error, "Failed to follow streamer")

            {:noreply, socket}
        end
    end
  end

  defp load_available_streamers(socket) do
    current_user = socket.assigns.current_user
    followed_ids = Enum.map(current_user.channels, & &1.id)

    # AIDEV-NOTE: Get all streamers excluding current user and already followed ones
    query =
      from u in User,
        where: u.role == :streamer,
        where: u.id != ^current_user.id

    query =
      if Enum.empty?(followed_ids) do
        query
      else
        from u in query, where: u.id not in ^followed_ids
      end

    available_streamers = Repo.all(query)

    assign(socket, :available_streamers, available_streamers)
  end
end
