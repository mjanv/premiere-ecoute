defmodule PremiereEcouteWeb.Sessions.SessionLive do
  @moduledoc """
  Session detail page

  Displays album metadata, session-level scores (viewer and streamer),
  and a per-track score breakdown. Reachable from the history cover wall
  at /retrospective/sessions/:id.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Profile
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Review
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.ReviewLikes
  alias PremiereEcoute.Sessions.Reviews
  alias PremiereEcoute.Sessions.Services.ReplayVideo
  alias PremiereEcouteWeb.ReturnTo

  @impl true
  def mount(%{"share_token" => share_token, "username" => _username}, _session, socket) do
    case ListeningSession.get_by_share_token(share_token) do
      nil ->
        socket
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/")
        |> then(fn socket -> {:ok, socket} end)

      listening_session ->
        listening_session = Repo.preload(listening_session, report: [:votes, :polls])

        {:ok, report} = Report.generate(listening_session)
        tracks = build_tracks(listening_session, report)

        reviews = Reviews.list_for_session(listening_session.id)
        review_ids = Enum.map(reviews, & &1.id)

        current_user = socket.assigns[:current_scope] && socket.assigns.current_scope.user

        liked_ids =
          if current_user,
            do: ReviewLikes.liked_review_ids(review_ids, current_user.id),
            else: MapSet.new()

        socket
        |> assign(:listening_session, listening_session)
        |> assign(:report, report)
        |> assign(:tracks, tracks)
        |> assign(:reviews, reviews)
        |> assign(:liked_ids, liked_ids)
        |> assign(:post_vote_eligible, !Sessions.has_voted?(listening_session, current_user))
        |> assign(:post_vote_modal_open, false)
        |> assign(:post_vote_selections, %{})
        |> assign(:review_modal_open, false)
        |> assign(:review_form, nil)
        |> assign(:editing_review, nil)
        |> assign(:replays_modal_open, false)
        |> assign(:replays_entries, [])
        |> assign(:replay_options, replay_options(current_user, listening_session))
        |> assign(:syncing_replays, false)
        |> then(fn socket -> {:ok, socket} end)
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, assign(socket, :back, ReturnTo.resolve(params["return_to"], history_path(socket)))}
  end

  @impl true
  def handle_event("open_post_vote_modal", _params, socket) do
    {:noreply, assign(socket, :post_vote_modal_open, true)}
  end

  @impl true
  def handle_event("close_post_vote_modal", _params, socket) do
    {:noreply, socket |> assign(:post_vote_modal_open, false) |> assign(:post_vote_selections, %{})}
  end

  @impl true
  def handle_event("set_post_vote", %{"track_id" => track_id, "note" => value}, socket) do
    selections = Map.put(socket.assigns.post_vote_selections, String.to_integer(track_id), value)
    {:noreply, assign(socket, :post_vote_selections, selections)}
  end

  @impl true
  def handle_event("submit_post_votes", _params, %{assigns: %{listening_session: session}} = socket) do
    current_user = socket.assigns[:current_scope] && socket.assigns.current_scope.user
    selections = socket.assigns.post_vote_selections

    if socket.assigns.post_vote_eligible && map_size(selections) > 0 do
      case Sessions.submit_post_votes(session, current_user, selections) do
        {:ok, report} ->
          socket
          |> assign(:report, report)
          |> assign(:tracks, build_tracks(session, report))
          |> assign(:post_vote_modal_open, false)
          |> assign(:post_vote_selections, %{})
          |> assign(:post_vote_eligible, false)
          |> put_flash(:info, gettext("Your votes have been submitted!"))
          |> then(fn socket -> {:noreply, socket} end)

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to submit votes"))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_review_modal", _params, socket) do
    current_scope = socket.assigns[:current_scope]
    session_id = socket.assigns.listening_session.id

    existing =
      if current_scope && current_scope.user do
        Reviews.get_for_user_and_session(session_id, current_scope.user.id)
      end

    role =
      if current_scope && current_scope.user do
        session = socket.assigns.listening_session
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
  def handle_event("update_review_form", %{"review" => params}, socket) do
    # Cast all user-editable fields to keep the form consistent between phx-change events.
    changeset =
      Ecto.Changeset.cast(socket.assigns.review_form.source, params, [
        :content,
        :tags_input,
        :watched_on,
        :watched_before,
        :rating,
        :like,
        :role
      ])

    {:noreply, assign(socket, :review_form, Phoenix.Component.to_form(changeset, as: :review))}
  end

  @impl true
  def handle_event("save_review", %{"review" => params}, socket) do
    current_scope = socket.assigns[:current_scope]
    session_id = socket.assigns.listening_session.id

    if current_scope && current_scope.user do
      # Tags arrive as a comma-separated string from the text input; convert to list.
      params = normalize_review_params(params)

      session = socket.assigns.listening_session

      result =
        case socket.assigns.editing_review do
          nil ->
            # Link review to both the session and its album (when album-sourced).
            extra = %{"session_id" => session_id, "album_id" => session.album_id}
            Reviews.create(current_scope.user, Map.merge(params, extra))

          review ->
            Reviews.update(review, params)
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
    session_id = socket.assigns.listening_session.id

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
      {:noreply, reload_reviews(socket, socket.assigns.listening_session.id, current_scope.user)}
    else
      {:noreply, put_flash(socket, :error, gettext("You must be logged in to like a review"))}
    end
  end

  @impl true
  def handle_event("open_replays_modal", _params, socket) do
    links = Enum.filter(socket.assigns.listening_session.replays || [], &is_binary(&1["url"]))
    entries = if links == [], do: [%{"label" => "", "url" => ""}], else: links

    {:noreply,
     socket
     |> assign(:replays_modal_open, true)
     |> assign(:replays_entries, entries)}
  end

  @impl true
  def handle_event("sync_replays", _params, %{assigns: %{listening_session: session}} = socket) do
    if owner?(socket) and not socket.assigns.syncing_replays do
      {:noreply,
       socket
       |> assign(:syncing_replays, true)
       |> start_async(:sync_replays, fn -> ReplayVideo.sync_replay_videos(session.id) end)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_replays_modal", _params, socket) do
    {:noreply, assign(socket, :replays_modal_open, false)}
  end

  @impl true
  def handle_event("add_replay_entry", _params, socket) do
    entries = socket.assigns.replays_entries ++ [%{"label" => "", "url" => ""}]
    {:noreply, assign(socket, :replays_entries, entries)}
  end

  @impl true
  def handle_event("remove_replay_entry", %{"index" => index}, socket) do
    entries = List.delete_at(socket.assigns.replays_entries, String.to_integer(index))
    entries = if entries == [], do: [%{"label" => "", "url" => ""}], else: entries
    {:noreply, assign(socket, :replays_entries, entries)}
  end

  @impl true
  def handle_event("save_replays", %{"replays" => params}, socket) do
    current_scope = socket.assigns[:current_scope]
    session = socket.assigns.listening_session

    if current_scope && current_scope.user && current_scope.user.id == session.user_id do
      # params arrive as %{"0" => %{"label" => ..., "url" => ...}, "1" => ...}.
      replays =
        params
        |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
        |> Enum.map(fn {k, submitted} ->
          ReplayVideo.manual_entry(submitted, Enum.at(socket.assigns.replays_entries, String.to_integer(k)))
        end)

      case ReplayVideo.save_links(session.id, replays) do
        {:ok, updated_session} ->
          {:noreply,
           socket
           |> assign(:listening_session, %{session | replays: updated_session.replays})
           |> assign(:replays_modal_open, false)
           |> put_flash(:info, gettext("Replays saved"))}

        {:error, :duplicate_replay} ->
          {:noreply, put_flash(socket, :error, gettext("Each replay can only be linked once"))}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to save replays"))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("Not authorized"))}
    end
  end

  # The YouTube title when the video is known, else the name of the replay.
  defp replay_title(%{"title" => title}) when is_binary(title) and title != "", do: title
  defp replay_title(replay), do: replay["label"] || replay["url"]

  # Under a title, the name of the replay and its channel. Otherwise the channel, or the host of the link.
  defp replay_subtitle(%{"title" => title} = replay) when is_binary(title) and title != "" do
    case Enum.reject([replay["label"], replay_source(replay)], &(&1 in [nil, ""])) do
      [] -> nil
      parts -> Enum.join(parts, " · ")
    end
  end

  defp replay_subtitle(replay), do: replay_source(replay)

  defp replay_source(%{"channel_title" => title}) when is_binary(title) and title != "", do: title

  defp replay_source(%{"url" => url}) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> String.replace_prefix(host, "www.", "")
      _ -> nil
    end
  end

  defp replay_source(_replay), do: nil

  @impl true
  def handle_async(:sync_replays, {:ok, {:ok, %{found: found, missing: missing, failed: failed}}}, socket) do
    session = socket.assigns.listening_session
    socket = assign(socket, :syncing_replays, false)
    names = fn replays -> Enum.map_join(replays, ", ", & &1.name) end

    socket =
      case ListeningSession.get(session.id) do
        %ListeningSession{replays: replays} -> assign(socket, :listening_session, %{session | replays: replays})
        nil -> socket
      end

    {:noreply,
     cond do
       failed != [] ->
         put_flash(socket, :error, gettext("YouTube could not be reached for: %{names}", names: names.(failed)))

       found != [] and missing != [] ->
         put_flash(
           socket,
           :info,
           gettext("Found: %{found}. Still missing: %{missing}", found: names.(found), missing: names.(missing))
         )

       found != [] ->
         put_flash(socket, :info, gettext("Found: %{found}", found: names.(found)))

       missing != [] ->
         put_flash(socket, :info, gettext("Nothing found yet. Still missing: %{missing}", missing: names.(missing)))

       true ->
         put_flash(socket, :info, gettext("No replay is missing"))
     end}
  end

  def handle_async(:sync_replays, _failure, socket) do
    {:noreply,
     socket
     |> assign(:syncing_replays, false)
     |> put_flash(:error, gettext("Could not look for the replays"))}
  end

  defp owner?(socket) do
    case socket.assigns[:current_scope] do
      %{user: %User{id: id}} -> id == socket.assigns.listening_session.user_id
      _ -> false
    end
  end

  defp replay_options(%User{id: id} = user, %ListeningSession{user_id: id}) do
    user |> Profile.get([:video_settings, :replays], []) |> Enum.map(&{&1.name, &1.id})
  end

  defp replay_options(_user, _session), do: []

  defp back_label(:album), do: gettext("Back to album")
  defp back_label(:artist), do: gettext("Back to artist")
  defp back_label(:single), do: gettext("Back to single")
  defp back_label(:home), do: gettext("Back to home")
  defp back_label(:profile), do: gettext("Back to profile")
  defp back_label(:sessions), do: gettext("Back to my sessions")
  defp back_label(_history), do: gettext("Back to history")

  defp history_path(socket) do
    case socket.assigns[:current_scope] do
      %{user: %{role: :viewer}} -> ~p"/sessions/retrospective/votes"
      _ -> ~p"/sessions/retrospective"
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

  # Builds [{track_album|playlist_track, track_summary}] from report summaries + preloaded tracks.
  defp build_tracks(%ListeningSession{source: :album} = session, report) do
    Enum.map(report.track_summaries, fn summary ->
      id = summary[:track_id] || summary["track_id"]
      %{track_album: Enum.find(session.album.tracks, &(&1.id == id)), track_summary: summary}
    end)
  end

  defp build_tracks(%ListeningSession{source: :playlist} = session, report) do
    Enum.map(report.track_summaries, fn summary ->
      id = summary[:track_id] || summary["track_id"]
      %{playlist_track: Enum.find(session.playlist.tracks, &(&1.id == id)), track_summary: summary}
    end)
  end

  defp build_tracks(_session, _report), do: []

  @doc "Builds vote distribution for a single viewer's votes (my_votes map from my_votes_by_track)."
  @spec my_vote_distribution(map(), map()) :: [{String.t(), number()}]
  def my_vote_distribution(my_votes, session) do
    votes = Enum.map(my_votes, fn {_track_id, value} -> %{value: value, is_streamer: false} end)
    individual = build_individual_distribution(votes, session)
    merge_distributions(individual, %{}, session)
  end

  @doc "Returns %{track_id => score_string} for a specific Twitch viewer from report votes."
  @spec my_votes_by_track(map(), term()) :: %{term() => String.t()}
  def my_votes_by_track(report, twitch_user_id) do
    report.votes
    |> Enum.reject(& &1.is_streamer)
    |> Enum.filter(&(&1.viewer_id == twitch_user_id))
    |> Map.new(fn v -> {v.track_id, v.value} end)
  end

  @doc """
  Builds distribution from report votes + polls for all vote options.

  Returns `[{label, pct}]` normalized 0-100 relative to max bucket, or `[]` if no votes.
  """
  @spec vote_distribution(map(), map(), :viewer | :streamer) :: [{String.t(), number()}]
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
