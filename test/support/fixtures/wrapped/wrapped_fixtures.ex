defmodule PremiereEcoute.Wrapped.WrappedFixtures do
  @moduledoc """
  Database fixtures for the Wrapped: listening sessions with votes, and stored recaps.

  Album `n` is "Album n" with two tracks, "Track One" (3:30) and "Track Two" (3:00). The default voter is the Twitch viewer `"viewer1"`.
  """

  import Ecto.Query

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.AlbumFixtures
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Discography.SingleFixtures
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcoute.Wrapped.Appearance
  alias PremiereEcoute.Wrapped.Recap

  @doc "Makes every cover download fail, so that cards get no colour."
  @spec stub_covers() :: :ok
  def stub_covers do
    Req.Test.stub(Appearance, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)
    :ok
  end

  @doc "Creates album `n`. `attrs` overrides the album."
  @spec album_record(integer(), map()) :: Album.t()
  def album_record(n, attrs \\ %{}) do
    tracks = [
      %Track{provider_ids: %{spotify: "track#{n}1"}, name: "Track One", track_number: 1, duration_ms: 210_000},
      %Track{provider_ids: %{spotify: "track#{n}2"}, name: "Track Two", track_number: 2, duration_ms: 180_000}
    ]

    defaults = %{provider_ids: %{spotify: "album#{n}"}, name: "Album #{n}", tracks: tracks}
    {:ok, album} = defaults |> Map.merge(attrs) |> AlbumFixtures.album_fixture() |> Album.create()

    album
  end

  @doc """
  Plays an album in a session of `streamer` and casts one track vote per value, on the first tracks.

  The album is album `n`, or an existing `%Album{}` to play it again. Options:

    * `:viewer` - Twitch id of the voter (`"viewer1"`)
    * `:album` - also casts an album vote with this value
    * `:others` - `[{viewer_id, value}]`, other viewers voting that value on every voted track
    * `:is_streamer` - casts the votes of the viewer as the streamer
    * `:vote_options` - scale of the session (0 to 10)
    * `:visibility` - visibility of the session (`:protected`)
    * `:voted_at` - time of every vote (now)
    * `:report` - `false` leaves the session without report
  """
  @spec listened(map(), integer() | Album.t(), [String.t()], keyword()) :: Album.t()
  def listened(streamer, album, values, opts \\ [])
  def listened(streamer, n, values, opts) when is_integer(n), do: listened(streamer, album_record(n), values, opts)

  def listened(streamer, %Album{} = album, values, opts) do
    viewer = opts[:viewer] || "viewer1"
    session = session(streamer, %{album_id: album.id}, opts)

    for {value, track} <- Enum.zip(values, album.tracks), {viewer_id, value} <- [{viewer, value} | opts[:others] || []] do
      vote(
        %Vote{viewer_id: viewer_id, session_id: session.id, track_id: track.id, value: value},
        viewer_id == viewer && opts[:is_streamer]
      )
    end

    if opts[:album],
      do: vote(%Vote{viewer_id: viewer, session_id: session.id, scope: :album, value: opts[:album]}, opts[:is_streamer])

    finish(session, opts)

    album
  end

  @doc "Plays single `n` (or an existing `%Single{}`) in a session of `streamer` and casts one vote. Takes the options of `listened/4`, except `:album`."
  @spec listened_single(map(), integer() | Single.t(), String.t(), keyword()) :: Single.t()
  def listened_single(streamer, single, value, opts \\ [])

  def listened_single(streamer, n, value, opts) when is_integer(n) do
    {:ok, single} =
      %{provider_ids: %{spotify: "single#{n}"}, name: "Single #{n}"}
      |> SingleFixtures.single_fixture()
      |> Single.create_if_not_exists()

    listened_single(streamer, single, value, opts)
  end

  def listened_single(streamer, %Single{} = single, value, opts) do
    viewer = opts[:viewer] || "viewer1"
    session = session(streamer, %{source: :track, single_id: single.id}, opts)

    for {viewer_id, value} <- [{viewer, value} | opts[:others] || []] do
      vote(
        %Vote{viewer_id: viewer_id, session_id: session.id, track_id: single.id, value: value},
        viewer_id == viewer && opts[:is_streamer]
      )
    end

    finish(session, opts)

    single
  end

  @doc "Stores a recap for a user and a year, at the current version and without cards unless `attrs` says otherwise."
  @spec recap_fixture(map(), integer(), map()) :: Recap.t()
  def recap_fixture(user, year, attrs \\ %{}) do
    defaults = %{cards: [], version: Recap.version(), computed_at: DateTime.utc_now(:second)}
    {:ok, recap} = Recap.store(user.id, year, Map.merge(defaults, attrs))

    recap
  end

  defp session(streamer, attrs, opts) do
    {:ok, session} =
      %{
        user_id: streamer.id,
        visibility: opts[:visibility] || :protected,
        vote_options: opts[:vote_options] || Enum.map(0..10, &Integer.to_string/1)
      }
      |> Map.merge(attrs)
      |> ListeningSession.create()

    session
  end

  defp vote(%Vote{} = vote, streamer?) do
    {:ok, vote} = Vote.create(%{vote | is_streamer: streamer? == true})

    vote
  end

  defp finish(session, opts) do
    if at = opts[:voted_at], do: Repo.update_all(from(v in Vote, where: v.session_id == ^session.id), set: [inserted_at: at])
    if opts[:report] != false, do: {:ok, _} = Report.generate(session)

    :ok
  end
end
