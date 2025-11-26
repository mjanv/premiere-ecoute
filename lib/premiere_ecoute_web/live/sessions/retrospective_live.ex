defmodule PremiereEcouteWeb.Sessions.RetrospectiveLive do
  @moduledoc """
  Retrospective view for ended listening sessions.
  Visibility is controlled by session.visibility setting (private/protected/public).
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Retrospective.VoteTrends

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_scope = socket.assigns[:current_scope]

    with listening_session when not is_nil(listening_session) <- ListeningSession.get(id),
         :ok <- validate_session_stopped(listening_session),
         :ok <- validate_authorization(listening_session, current_scope) do
      mount_retrospective(socket, listening_session)
    else
      nil ->
        redirect_with_error(socket, "Session not found")

      {:error, :not_stopped} ->
        redirect_with_error(socket, "Retrospective only available for ended sessions")

      {:error, :unauthorized, listening_session} ->
        error_message = authorization_error_message(listening_session, current_scope)
        redirect_with_error(socket, error_message)
    end
  end

  defp validate_session_stopped(%{status: :stopped}), do: :ok
  defp validate_session_stopped(_), do: {:error, :not_stopped}

  defp validate_authorization(listening_session, current_scope) do
    if Sessions.can_view_retrospective?(listening_session, current_scope) do
      :ok
    else
      {:error, :unauthorized, listening_session}
    end
  end

  defp redirect_with_error(socket, message) do
    socket
    |> put_flash(:error, message)
    |> redirect(to: ~p"/")
    |> then(fn socket -> {:ok, socket} end)
  end

  defp mount_retrospective(socket, listening_session) do
    socket
    |> assign(:listening_session, listening_session)
    |> assign_async(:report, fn ->
      case Report.generate(listening_session) do
        {:ok, report} -> {:ok, %{report: report}}
        error -> {:error, error}
      end
    end)
    |> assign_async([:most_liked, :least_liked], fn ->
      calculate_track_extremes(listening_session.id)
    end)
    |> then(fn socket -> {:ok, socket} end)
  end

  defp calculate_track_extremes(session_id) do
    consensus =
      session_id
      |> VoteTrends.track_distribution()
      |> VoteTrends.consensus()

    scores = Enum.map(consensus, fn {_, %{score: score}} -> score end)

    most_liked_score = Enum.max(scores)
    {most_liked, _} = Enum.find(consensus, &match?({_, %{score: ^most_liked_score}}, &1))

    least_liked_score = Enum.min(scores)
    {least_liked, _} = Enum.find(consensus, &match?({_, %{score: ^least_liked_score}}, &1))

    {:ok, %{most_liked: most_liked, least_liked: least_liked}}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  defp authorization_error_message(%{visibility: :private}, nil) do
    "This retrospective is private. Please log in if you have access."
  end

  defp authorization_error_message(%{visibility: :private}, _scope) do
    "This retrospective is private and can only be viewed by the streamer."
  end

  defp authorization_error_message(%{visibility: :protected}, nil) do
    "This retrospective is protected. Please log in to view."
  end

  defp authorization_error_message(_session, _scope) do
    "You don't have permission to view this retrospective."
  end

  defp session_average_score(nil), do: "N/A"

  defp session_average_score(report) do
    case report.session_summary do
      %{viewer_score: score} when is_number(score) -> Float.round(score, 1)
      %{viewer_score: score} when is_binary(score) -> score
      _ -> "N/A"
    end
  end

  defp session_streamer_score(nil), do: "N/A"

  defp session_streamer_score(report) do
    case report.session_summary do
      %{streamer_score: score} when is_number(score) -> Float.round(score, 1)
      %{streamer_score: score} when is_binary(score) -> score
      _ -> "N/A"
    end
  end

  defp track_average_score(_track_id, nil), do: "N/A"

  defp track_average_score(track_id, report) do
    case Enum.find(report.track_summaries, &(&1.track_id == track_id)) do
      nil ->
        "N/A"

      track_summary ->
        case track_summary.viewer_score do
          score when is_number(score) -> Float.round(score, 1)
          score when is_binary(score) -> score
          _ -> "N/A"
        end
    end
  end

  defp track_streamer_score(_track_id, nil), do: "N/A"

  defp track_streamer_score(track_id, report) do
    case Enum.find(report.track_summaries, &(&1.track_id == track_id)) do
      nil ->
        "N/A"

      track_summary ->
        case track_summary.streamer_score do
          score when is_number(score) -> Float.round(score, 1)
          score when is_binary(score) -> score
          _ -> "N/A"
        end
    end
  end

  defp track_vote_distribution(_track_id, nil, session),
    do: for(rating <- session_vote_options(session), do: {rating, 0})

  defp track_vote_distribution(track_id, report, session) do
    # Calculate distribution from individual votes
    individual_distribution =
      report.votes
      |> Enum.filter(&(&1.track_id == track_id))
      |> Enum.group_by(fn vote ->
        # Convert string values to integers for numeric scale if vote_options are numeric
        if vote_options_are_numeric?(session) do
          String.to_integer(vote.value)
        else
          vote.value
        end
      end)
      |> Map.new(fn {value, votes} -> {value, length(votes)} end)

    # Calculate distribution from poll votes (handle if polls exist)
    poll_distribution =
      report.polls
      |> Enum.filter(&(&1.track_id == track_id))
      |> Enum.reduce(%{}, fn poll, acc ->
        poll.votes
        |> Enum.reduce(acc, fn {rating_str, count}, inner_acc ->
          # Handle both numeric and string ratings
          rating = if String.match?(rating_str, ~r/^\d+$/), do: String.to_integer(rating_str), else: rating_str
          Map.update(inner_acc, rating, count, &(&1 + count))
        end)
      end)

    for rating <- session_vote_options(session) do
      individual_count = Map.get(individual_distribution, rating, 0)
      poll_count = Map.get(poll_distribution, rating, 0)
      total_count = individual_count + poll_count
      {rating, total_count}
    end
  end

  defp session_vote_distribution(nil, session),
    do: for(rating <- session_vote_options(session), do: {rating, 0})

  defp session_vote_distribution(report, session) do
    # Calculate distribution from all individual votes
    individual_distribution =
      report.votes
      |> Enum.group_by(fn vote ->
        # Convert string values to integers for numeric scale if vote_options are numeric
        if vote_options_are_numeric?(session) do
          String.to_integer(vote.value)
        else
          vote.value
        end
      end)
      |> Map.new(fn {value, votes} -> {value, length(votes)} end)

    # Calculate distribution from all poll votes
    poll_distribution =
      report.polls
      |> Enum.reduce(%{}, fn poll, acc ->
        poll.votes
        |> Enum.reduce(acc, fn {rating_str, count}, inner_acc ->
          # Handle both numeric and string ratings
          rating = if String.match?(rating_str, ~r/^\d+$/), do: String.to_integer(rating_str), else: rating_str
          Map.update(inner_acc, rating, count, &(&1 + count))
        end)
      end)

    for rating <- session_vote_options(session) do
      individual_count = Map.get(individual_distribution, rating, 0)
      poll_count = Map.get(poll_distribution, rating, 0)
      total_count = individual_count + poll_count
      {rating, total_count}
    end
  end

  defp session_vote_options(session) do
    case session.vote_options do
      options when is_list(options) and length(options) > 0 ->
        if vote_options_are_numeric?(session) do
          Enum.map(options, &String.to_integer/1)
        else
          options
        end

      _ ->
        1..10 |> Enum.to_list()
    end
  end

  defp vote_options_are_numeric?(session) do
    case session.vote_options do
      options when is_list(options) ->
        Enum.all?(options, fn option ->
          case Integer.parse(option) do
            {_, ""} -> true
            _ -> false
          end
        end)

      # Default to numeric
      _ ->
        true
    end
  end

  defp vote_option_color(rating, session) do
    vote_options = session.vote_options || ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
    total_options = length(vote_options)

    # Find the index of this vote option
    index = Enum.find_index(vote_options, &(to_string(&1) == to_string(rating))) || 0

    cond do
      # Special handling for common non-numeric options
      rating in ["smash", "pass"] ->
        if rating == "smash",
          do: "bg-gradient-to-t from-pink-500 to-purple-500",
          else: "bg-gradient-to-t from-red-500 to-pink-500"

      # For numeric options, use synthwave gradient based on position
      vote_options_are_numeric?(session) and total_options <= 5 ->
        case index do
          0 -> "bg-gradient-to-t from-red-500 to-pink-500"
          1 -> "bg-gradient-to-t from-pink-500 to-purple-500"
          2 -> "bg-gradient-to-t from-purple-500 to-indigo-500"
          3 -> "bg-gradient-to-t from-indigo-500 to-cyan-500"
          4 -> "bg-gradient-to-t from-cyan-500 to-pink-500"
          _ -> "bg-gradient-to-t from-purple-500 to-pink-500"
        end

      vote_options_are_numeric?(session) and total_options <= 11 ->
        synthwave_colors = [
          "bg-gradient-to-t from-red-500 to-pink-500",
          "bg-gradient-to-t from-pink-500 to-rose-500",
          "bg-gradient-to-t from-rose-500 to-purple-500",
          "bg-gradient-to-t from-purple-500 to-violet-500",
          "bg-gradient-to-t from-violet-500 to-indigo-500",
          "bg-gradient-to-t from-indigo-500 to-blue-500",
          "bg-gradient-to-t from-blue-500 to-cyan-500",
          "bg-gradient-to-t from-cyan-500 to-teal-500",
          "bg-gradient-to-t from-teal-500 to-cyan-400",
          "bg-gradient-to-t from-cyan-400 to-pink-400",
          "bg-gradient-to-t from-pink-400 to-purple-400"
        ]

        Enum.at(synthwave_colors, index, "bg-gradient-to-t from-purple-500 to-pink-500")

      true ->
        synthwave_colors = [
          "bg-gradient-to-t from-pink-500 to-purple-500",
          "bg-gradient-to-t from-purple-500 to-indigo-500",
          "bg-gradient-to-t from-indigo-500 to-cyan-500",
          "bg-gradient-to-t from-cyan-500 to-pink-500",
          "bg-gradient-to-t from-red-500 to-pink-500",
          "bg-gradient-to-t from-violet-500 to-purple-500"
        ]

        Enum.at(synthwave_colors, rem(index, length(synthwave_colors)), "bg-gradient-to-t from-purple-500 to-pink-500")
    end
  end

  defp build_track_data_attributes(listening_session, report) do
    tracks = get_session_tracks(listening_session)

    case tracks do
      tracks when is_list(tracks) and length(tracks) > 0 ->
        tracks
        |> Enum.with_index()
        |> Enum.reduce([], fn {track, index}, acc ->
          track_id = get_track_id(track, listening_session)
          viewer_score = track_average_score(track_id, report)
          streamer_score = track_streamer_score(track_id, report)

          [
            {"data-track#{index}-name", "#{index + 1}. #{get_track_name(track)}"},
            {"data-track#{index}-viewer-score", viewer_score},
            {"data-track#{index}-streamer-score", streamer_score},
            {"data-track#{index}-id", track_id}
            | acc
          ]
        end)
        |> Enum.reverse()

      _ ->
        []
    end
  end

  defp get_session_tracks(%{album: %{tracks: tracks}}) when is_list(tracks), do: tracks
  defp get_session_tracks(%{playlist: %{tracks: tracks}}) when is_list(tracks), do: tracks
  defp get_session_tracks(_), do: []

  defp get_track_id(%{id: id}, %{source: :album}), do: id
  defp get_track_id(%{id: id}, %{source: :playlist}), do: id
  defp get_track_id(track, _), do: Map.get(track, :id) || Map.get(track, :track_id)

  defp get_track_name(%{name: name}), do: name
  defp get_track_name(track), do: Map.get(track, :name, "Unknown Track")

  defp get_session_title(%{album: %{name: name}}) when not is_nil(name), do: name
  defp get_session_title(%{playlist: %{title: title}}) when not is_nil(title), do: title
  defp get_session_title(_), do: "Unknown"

  defp get_session_artist(%{album: %{artist: artist}}) when not is_nil(artist), do: artist
  defp get_session_artist(%{playlist: %{owner_name: owner_name}}) when not is_nil(owner_name), do: "by #{owner_name}"
  defp get_session_artist(_), do: "Unknown Artist"

  # Calculate dynamic bar height based on vote count and maximum votes in the dataset.
  # Ensures bars scale proportionally and don't exceed container height.
  defp calculate_bar_height(votes, max_votes, container_height, min_height) do
    cond do
      votes == 0 ->
        0

      max_votes == 0 ->
        min_height

      true ->
        # Use 85% of container height for maximum bar
        max_bar_height = container_height * 0.85
        scale_factor = max_bar_height / max_votes
        calculated_height = votes * scale_factor

        # Ensure minimum height for visibility
        max(calculated_height, min_height)
        |> round()
    end
  end

  # Format vote count for display, using abbreviated format for large numbers.
  defp format_vote_count(count) when is_integer(count) do
    cond do
      count < 1_000 -> Integer.to_string(count)
      count < 10_000 -> "#{Float.round(count / 1000, 1)}k"
      count < 1_000_000 -> "#{round(count / 1000)}k"
      true -> "#{Float.round(count / 1_000_000, 1)}M"
    end
  end

  defp format_vote_count(_), do: "0"

  # Determine if vote count should be displayed inside or above the bar based on bar height.
  defp vote_count_position(bar_height, min_height_for_inside \\ 30) do
    if bar_height >= min_height_for_inside do
      :inside
    else
      :above
    end
  end

  # Calculate responsive font size class for vote counts based on maximum vote count.
  defp vote_count_font_size(max_votes) do
    cond do
      max_votes < 100 -> "text-lg"
      max_votes < 1000 -> "text-base"
      true -> "text-sm"
    end
  end

  # Calculate responsive padding for histogram bars based on number of vote options.
  defp bar_padding_class(vote_option_count) do
    cond do
      vote_option_count <= 5 -> "px-2"
      vote_option_count <= 10 -> "px-1"
      vote_option_count <= 15 -> "px-0.5"
      true -> "px-0"
    end
  end
end
