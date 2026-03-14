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

        socket
        |> assign(:user, user)
        |> assign(:sessions, sessions)
        |> assign(:votes, votes)
        |> assign(:reviews, reviews)
        |> assign(:liked_ids, liked_ids)
        |> assign(:stat_primary, stat_primary)
        |> assign(:review_count, review_count)
        |> then(fn s -> {:ok, s} end)
    end
  end
end
