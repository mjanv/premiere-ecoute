defmodule PremiereEcoute.Wrapped.Listens do
  @moduledoc """
  What a viewer voted on during a year.

  Takes the votes of a viewer from Sessions and the albums and singles from Discography, and merges them into a flat list of `PremiereEcoute.Wrapped.Listen`: one per album, per rated track and per single. Playlist and free sessions are left out. Votes cast as a streamer count like the others. Scores are brought to a /10 scale so that sessions with different vote scales compare; sessions with a non-numeric scale keep a `nil` score (same rule as `Report.generate/1`).
  """

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Wrapped.Listen
  alias PremiereEcoute.Wrapped.Listen.Result

  @doc """
  Lists what a user voted on during a year, oldest vote first: one listen per album, per rated track of these albums, and per single.
  """
  @spec all(User.t(), integer()) :: [Listen.t()]
  def all(%User{} = user, year) do
    Enum.sort_by(albums(user, year) ++ singles(user, year), & &1.result.voted_at, DateTime)
  end

  defp albums(user, year) do
    votes = Sessions.get_viewer_votes_by_year(user, year, :album)
    albums = votes |> Enum.map(& &1.album_id) |> Enum.uniq() |> Discography.list_albums_by_ids() |> Map.new(&{&1.id, &1})

    votes
    |> session_listens()
    |> Enum.group_by(& &1.album_id)
    |> Enum.flat_map(fn {album_id, listens} -> album_listens(albums[album_id], listens) end)
  end

  defp singles(user, year) do
    votes = Sessions.get_viewer_votes_by_year(user, year, :track)
    singles = votes |> Enum.map(& &1.single_id) |> Enum.uniq() |> Discography.list_singles_by_ids() |> Map.new(&{&1.id, &1})

    votes
    |> session_listens()
    |> Enum.group_by(& &1.single_id)
    |> Enum.flat_map(fn {single_id, listens} -> single_listens(singles[single_id], listens) end)
  end

  # One entry per session, with the scores of the viewer and of the chat
  defp session_listens(votes) do
    reports = votes |> Enum.map(& &1.session_id) |> Enum.uniq() |> Sessions.get_reports() |> Map.new(&{&1.session_id, &1})

    votes
    |> Enum.group_by(& &1.session_id)
    |> Enum.map(fn {session_id, votes} -> session_listen(votes, reports[session_id]) end)
  end

  defp session_listen([%{vote_options: options} = first | _] = votes, report) do
    scale = scale(options)
    {album_votes, track_votes} = Enum.split_with(votes, &(&1.scope == :album))
    averages = report |> track_summaries() |> Map.new(&{&1["track_id"], &1})

    tracks =
      if scale do
        for vote <- track_votes do
          %{
            track_id: vote.track_id,
            score: normalize(vote.value, scale),
            chat_score: chat_score(averages[vote.track_id], scale),
            voted_at: vote.voted_at
          }
        end
      else
        []
      end

    %{
      album_id: first.album_id,
      single_id: first.single_id,
      streamer: first.streamer,
      voted_at: votes |> Enum.map(& &1.voted_at) |> Enum.min(DateTime),
      score: scale && session_score(album_votes, tracks, scale),
      chat_score: scale && chat_score(report && report.session_summary, scale),
      tracks: tracks
    }
  end

  defp track_summaries(%{track_summaries: [_ | _] = summaries}), do: summaries
  defp track_summaries(_report), do: []

  # Album vote first, else the average of the track votes
  defp session_score([%{value: value} | _], _tracks, scale), do: normalize(value, scale)
  defp session_score([], [], _scale), do: nil
  defp session_score([], tracks, _scale), do: tracks |> Enum.map(& &1.score) |> mean()

  defp chat_score(%{"viewer_score" => score}, scale) when is_number(score), do: normalize(score, scale)
  defp chat_score(_summary, _scale), do: nil

  # The highest option of a numeric scale, `nil` for text scales and scales that do not fit on /10
  defp scale(options) do
    with [_ | _] <- options,
         parsed = Enum.map(options, &Integer.parse/1),
         true <- Enum.all?(parsed, &match?({_, ""}, &1)),
         max when max in 1..10 <- parsed |> Enum.map(&elem(&1, 0)) |> Enum.max() do
      max
    else
      _ -> nil
    end
  end

  defp normalize(value, scale) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} -> normalize(number, scale)
      _ -> nil
    end
  end

  defp normalize(value, scale), do: Float.round(value / scale * 10, 1)

  defp mean(values) do
    case Enum.reject(values, &is_nil/1) do
      [] -> nil
      values -> Float.round(Enum.sum(values) / length(values), 1)
    end
  end

  defp album_listens(nil, _listens), do: []

  # The album, then each track the viewer rated
  defp album_listens(%Album{} = album, listens) do
    tracks = Map.new(album.tracks, &{&1.id, %{&1 | album: album}})

    rated =
      for listen <- listens, vote <- listen.tracks, vote.score, track = tracks[vote.track_id] do
        result = %Result{voted_at: vote.voted_at, score: vote.score, chat_score: vote.chat_score, streamers: [listen.streamer]}

        %Listen{entity: track, result: result}
      end

    [%Listen{entity: album, result: result(listens)} | rated]
  end

  defp single_listens(nil, _listens), do: []
  defp single_listens(%Single{} = single, listens), do: [%Listen{entity: single, result: result(listens)}]

  # One result over every session an album or a single was played in
  defp result(listens) do
    %Result{
      voted_at: listens |> Enum.map(& &1.voted_at) |> Enum.min(DateTime),
      score: listens |> Enum.map(& &1.score) |> mean(),
      chat_score: listens |> Enum.map(& &1.chat_score) |> mean(),
      streamers: Enum.map(listens, & &1.streamer)
    }
  end
end
