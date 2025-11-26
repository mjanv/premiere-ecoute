defmodule PremiereEcoute.Sessions.ListeningSessionFixtures do
  @moduledoc """
  Listening session fixtures.

  Provides factory functions to generate test listening session and track data for use in test suites.
  """

  import PremiereEcoute.Discography.AlbumFixtures

  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession

  def session_fixture(attrs \\ %{}) do
    album = album_fixture()

    default_attrs = %{
      status: :preparing,
      source: :album,
      visibility: :protected,
      options: %{"votes" => 0, "scores" => 0, "next_track" => 0},
      vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
      album_id: album.id
    }

    {:ok, session} =
      %ListeningSession{}
      |> ListeningSession.changeset(Map.merge(default_attrs, attrs))
      |> Repo.insert()

    Repo.preload(session, [:album, :user])
  end

  def track_fixture(attrs \\ %{}) do
    album_id = Map.get(attrs, :album_id)

    if album_id do
      # Get existing album and create track for it
      _album = Repo.get!(PremiereEcoute.Discography.Album, album_id)
      track_data = List.first(album_fixture().tracks)

      {:ok, inserted_track} =
        %Track{}
        |> Track.changeset(%{
          provider: track_data.provider,
          track_id: "#{track_data.track_id}_#{System.unique_integer([:positive])}",
          name: track_data.name,
          track_number: track_data.track_number,
          duration_ms: track_data.duration_ms,
          album_id: album_id
        })
        |> Repo.insert()

      inserted_track
    else
      # Create new album and track
      album = album_fixture()
      track = List.first(album.tracks)

      {:ok, inserted_track} =
        %Track{}
        |> Track.changeset(%{
          provider: track.provider,
          track_id: track.track_id,
          name: track.name,
          track_number: track.track_number,
          duration_ms: track.duration_ms,
          album_id: album.id
        })
        |> Repo.insert()

      inserted_track
    end
  end
end
