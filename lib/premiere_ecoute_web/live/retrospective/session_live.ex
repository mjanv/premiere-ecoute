defmodule PremiereEcouteWeb.Retrospective.SessionLive do
  @moduledoc """
  Session detail page within the retrospective.

  Displays album metadata, session-level scores (viewer and streamer),
  and a per-track score breakdown. Reachable from the history cover wall
  at /retrospective/sessions/:id.
  """

  use PremiereEcouteWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession.Review
  alias PremiereEcoute.Sessions.ReviewLikes
  alias PremiereEcoute.Sessions.Reviews

  @impl true
  def mount(%{"id" => session_id}, _session, socket) do
    session_id_int = String.to_integer(session_id)

    reviews = Reviews.list_for_session(session_id_int)
    review_ids = Enum.map(reviews, & &1.id)

    current_user = socket.assigns[:current_scope] && socket.assigns.current_scope.user

    liked_ids =
      if current_user,
        do: ReviewLikes.liked_review_ids(review_ids, current_user.id),
        else: MapSet.new()

    socket =
      socket
      |> assign(:session_id, session_id_int)
      |> assign(:session_data, AsyncResult.loading())
      |> assign(:reviews, reviews)
      |> assign(:liked_ids, liked_ids)
      |> assign(:review_modal_open, false)
      |> assign(:review_form, nil)
      |> assign(:editing_review, nil)
      |> assign_async(:session_data, fn -> load_session(session_id) end)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("open_review_modal", _params, socket) do
    current_scope = socket.assigns[:current_scope]
    session_id = socket.assigns.session_id

    existing =
      if current_scope && current_scope.user do
        Reviews.get_for_user(session_id, current_scope.user.id)
      end

    role =
      if current_scope && current_scope.user && socket.assigns.session_data.result do
        session = socket.assigns.session_data.result.session
        if current_scope.user.id == session.user_id, do: :streamer, else: :viewer
      else
        :viewer
      end

    changeset =
      if existing do
        Review.changeset(existing, Map.from_struct(existing))
      else
        Review.changeset(%Review{}, %{role: role, watched_on: Date.utc_today()})
      end

    {:noreply,
     socket
     |> assign(:review_modal_open, true)
     |> assign(:review_form, Phoenix.Component.to_form(changeset, as: :review))
     |> assign(:editing_review, existing)}
  end

  @impl true
  def handle_event("close_review_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:review_modal_open, false)
     |> assign(:review_form, nil)
     |> assign(:editing_review, nil)}
  end

  @impl true
  def handle_event("set_review_rating", %{"rating" => rating}, socket) do
    {value, _} = Float.parse(rating)
    changeset = Ecto.Changeset.put_change(socket.assigns.review_form.source, :rating, value)
    {:noreply, assign(socket, :review_form, Phoenix.Component.to_form(changeset, as: :review))}
  end

  @impl true
  def handle_event("toggle_review_like", _params, socket) do
    form = socket.assigns.review_form
    next = if form[:like].value == true, do: nil, else: true
    changeset = Ecto.Changeset.put_change(form.source, :like, next)
    {:noreply, assign(socket, :review_form, Phoenix.Component.to_form(changeset, as: :review))}
  end

  @impl true
  def handle_event("save_review", %{"review" => params}, socket) do
    current_scope = socket.assigns[:current_scope]
    session_id = socket.assigns.session_id

    if current_scope && current_scope.user do
      # AIDEV-NOTE: tags arrive as comma-separated string from the text input; convert to list
      params = normalize_review_params(params)

      result =
        case socket.assigns.editing_review do
          nil -> Reviews.create(session_id, current_scope.user, params)
          review -> Reviews.update(review, params)
        end

      case result do
        {:ok, _} ->
          {:noreply,
           socket
           |> reload_reviews(session_id, current_scope.user)
           |> assign(:review_modal_open, false)
           |> assign(:review_form, nil)
           |> assign(:editing_review, nil)
           |> put_flash(:info, gettext("Review saved"))}

        {:error, changeset} ->
          {:noreply, assign(socket, :review_form, Phoenix.Component.to_form(changeset, as: :review))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("You must be logged in to write a review"))}
    end
  end

  @impl true
  def handle_event("delete_review", %{"id" => id}, socket) do
    current_scope = socket.assigns[:current_scope]
    session_id = socket.assigns.session_id

    if current_scope && current_scope.user do
      case Reviews.delete(String.to_integer(id), current_scope.user) do
        {:ok, _} ->
          {:noreply,
           socket
           |> reload_reviews(session_id, current_scope.user)
           |> put_flash(:info, gettext("Review deleted"))}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, gettext("Review not found"))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("You must be logged in to delete a review"))}
    end
  end

  @impl true
  def handle_event("toggle_like_review", %{"id" => id}, socket) do
    current_scope = socket.assigns[:current_scope]

    if current_scope && current_scope.user do
      {:ok, _} = ReviewLikes.toggle(String.to_integer(id), current_scope.user)
      {:noreply, reload_reviews(socket, socket.assigns.session_id, current_scope.user)}
    else
      {:noreply, put_flash(socket, :error, gettext("You must be logged in to like a review"))}
    end
  end

  defp reload_reviews(socket, session_id, user) do
    reviews = Reviews.list_for_session(session_id)
    review_ids = Enum.map(reviews, & &1.id)

    socket
    |> assign(:reviews, reviews)
    |> assign(:liked_ids, ReviewLikes.liked_review_ids(review_ids, user.id))
  end

  defp normalize_review_params(params) do
    tags =
      params
      |> Map.get("tags_input", "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    like =
      case Map.get(params, "like") do
        "true" -> true
        "false" -> false
        _ -> nil
      end

    params
    |> Map.put("tags", tags)
    |> Map.delete("tags_input")
    |> Map.put("like", like)
  end

  defp load_session(session_id) do
    # AIDEV-NOTE: tries album first, then single, then playlist — matches ListeningSession.source values
    result =
      with {:error, :not_found} <- Sessions.get_album_session_details(session_id),
           {:error, :not_found} <- Sessions.get_single_session_details(session_id),
           {:error, :not_found} <- Sessions.get_playlist_session_details(session_id) do
        {:ok, nil}
      end

    case result do
      {:ok, data} -> {:ok, %{session_data: data}}
    end
  end

  # AIDEV-NOTE: builds vote distribution for a single viewer's votes (my_votes map from my_votes_by_track).
  def my_vote_distribution(my_votes, session) do
    votes = Enum.map(my_votes, fn {_track_id, value} -> %{value: value, is_streamer: false} end)
    individual = build_individual_distribution(votes, session)
    merge_distributions(individual, %{}, session)
  end

  # AIDEV-NOTE: returns %{track_id => score_string} for a specific Twitch viewer from report votes.
  def my_votes_by_track(report, twitch_user_id) do
    report.votes
    |> Enum.reject(& &1.is_streamer)
    |> Enum.filter(&(&1.viewer_id == twitch_user_id))
    |> Map.new(fn v -> {v.track_id, v.value} end)
  end

  # AIDEV-NOTE: builds distribution from report votes + polls for all vote options.
  # Returns [{label, pct}] normalized 0-100 relative to max bucket, or [] if no votes.
  def vote_distribution(report, session, :viewer) do
    individual =
      report.votes
      |> Enum.reject(& &1.is_streamer)
      |> build_individual_distribution(session)

    poll =
      report.polls
      |> build_poll_distribution()

    merge_distributions(individual, poll, session)
  end

  def vote_distribution(report, session, :streamer) do
    individual =
      report.votes
      |> Enum.filter(& &1.is_streamer)
      |> build_individual_distribution(session)

    merge_distributions(individual, %{}, session)
  end

  defp build_individual_distribution(votes, session) do
    votes
    |> Enum.group_by(fn vote ->
      if vote_options_numeric?(session),
        do: String.to_integer(vote.value),
        else: vote.value
    end)
    |> Map.new(fn {value, vs} -> {value, length(vs)} end)
  end

  defp build_poll_distribution(polls) do
    polls
    |> Enum.reduce(%{}, fn poll, acc ->
      Enum.reduce(poll.votes, acc, fn {rating_str, count}, inner ->
        rating =
          if String.match?(rating_str, ~r/^\d+$/),
            do: String.to_integer(rating_str),
            else: rating_str

        Map.update(inner, rating, count, &(&1 + count))
      end)
    end)
  end

  defp merge_distributions(individual, poll, session) do
    counts =
      for option <- vote_options(session) do
        {option, Map.get(individual, option, 0) + Map.get(poll, option, 0)}
      end

    max_count = counts |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 0 end)
    total = counts |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    if max_count == 0 do
      []
    else
      Enum.map(counts, fn {option, count} ->
        bar_pct = round(count / max_count * 100)
        real_pct = round(count / total * 100)
        {option, bar_pct, real_pct}
      end)
    end
  end

  defp vote_options(session) do
    case session.vote_options do
      options when is_list(options) and length(options) > 0 ->
        if vote_options_numeric?(session),
          do: Enum.map(options, &String.to_integer/1),
          else: options

      _ ->
        Enum.to_list(1..10)
    end
  end

  defp vote_options_numeric?(session) do
    Enum.all?(session.vote_options || [], fn o ->
      match?({_, ""}, Integer.parse(o))
    end)
  end
end
