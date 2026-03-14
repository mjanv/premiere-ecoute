defmodule PremiereEcouteWeb.Accounts.UserLive do
  @moduledoc """
  Public profile page for a user account.

  Shows recent sessions for streamers and recent vote reviews for viewers.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ReviewLikes
  alias PremiereEcoute.Sessions.Reviews

  alias PremiereEcoute.Accounts.User.Follow

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/users")}

      user ->
        {sessions, votes, stat_primary} =
          if user.role in [:streamer, :admin] do
            {Sessions.stopped_sessions(user, 12), [], Sessions.ListeningSession.count_stopped_sessions(user)}
          else
            viewer_sessions =
              if user.twitch,
                do: Sessions.ListeningSession.viewer_voted_sessions(user.twitch.user_id),
                else: []

            {viewer_sessions, [], Sessions.count_viewer_votes(user)}
          end

        reviews = Reviews.list_for_user(user.id)
        review_ids = Enum.map(reviews, & &1.id)
        review_count = Reviews.count_for_user(user.id)

        current_user = socket.assigns[:current_scope] && socket.assigns.current_scope.user

        liked_ids =
          if current_user,
            do: ReviewLikes.liked_review_ids(review_ids, current_user.id),
            else: MapSet.new()

        following =
          if current_user && current_user.id != user.id,
            do: Follow.following?(current_user.id, user.id),
            else: false

        follower_count = Follow.follower_count(user.id)

        socket
        |> assign(:user, user)
        |> assign(:sessions, sessions)
        |> assign(:votes, votes)
        |> assign(:reviews, reviews)
        |> assign(:liked_ids, liked_ids)
        |> assign(:stat_primary, stat_primary)
        |> assign(:review_count, review_count)
        |> assign(:following, following)
        |> assign(:follower_count, follower_count)
        |> then(fn s -> {:ok, s} end)
    end
  end

  @impl true
  def handle_event("follow", _params, socket) do
    current_user = socket.assigns.current_scope.user
    user = socket.assigns.user

    case Accounts.follow(current_user, user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:following, true)
         |> assign(:follower_count, socket.assigns.follower_count + 1)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not follow user")}
    end
  end

  @impl true
  def handle_event("unfollow", _params, socket) do
    current_user = socket.assigns.current_scope.user
    user = socket.assigns.user

    case Accounts.unfollow(current_user, user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:following, false)
         |> assign(:follower_count, socket.assigns.follower_count - 1)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not unfollow user")}
    end
  end
end
