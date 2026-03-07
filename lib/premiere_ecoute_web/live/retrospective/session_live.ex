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

  @impl true
  def mount(%{"id" => session_id}, _session, socket) do
    socket =
      socket
      |> assign(:session_id, session_id)
      |> assign(:session_data, AsyncResult.loading())
      |> assign_async(:session_data, fn -> load_session(session_id) end)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
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
