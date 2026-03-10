defmodule PremiereEcoute.Collections.CollectionSessionFixtures do
  @moduledoc """
  Collection session fixtures.

  Provides factory functions for collection sessions and decisions in test suites.
  """

  alias PremiereEcoute.Collections.CollectionDecision
  alias PremiereEcoute.Collections.CollectionSession
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Repo

  @doc """
  Creates a LibraryPlaylist fixture for a user.
  """
  @spec collection_library_playlist_fixture(map(), map()) :: LibraryPlaylist.t()
  def collection_library_playlist_fixture(user, attrs \\ %{}) do
    playlist_id = "playlist_#{System.unique_integer([:positive])}"

    default_attrs = %{
      provider: :spotify,
      playlist_id: playlist_id,
      title: "Test Playlist",
      url: "https://open.spotify.com/playlist/#{playlist_id}",
      track_count: 10
    }

    {:ok, playlist} = LibraryPlaylist.create(user, Map.merge(default_attrs, attrs))
    playlist
  end

  @doc """
  Creates a CollectionSession fixture with two library playlists.
  """
  @spec collection_session_fixture(map(), map()) :: CollectionSession.t()
  def collection_session_fixture(user, attrs \\ %{}) do
    origin = collection_library_playlist_fixture(user, %{title: "Origin Playlist"})
    destination = collection_library_playlist_fixture(user, %{title: "Destination Playlist"})

    default_attrs = %{
      rule: :ordered,
      selection_mode: :streamer_choice,
      user_id: user.id,
      origin_playlist_id: origin.id,
      destination_playlist_id: destination.id
    }

    {:ok, session} =
      %CollectionSession{}
      |> CollectionSession.changeset(Map.merge(default_attrs, attrs))
      |> Repo.insert()

    Repo.preload(session, [:user, :origin_playlist, :destination_playlist, :decisions])
  end

  @doc """
  Creates a CollectionDecision fixture for a session.
  """
  @spec collection_decision_fixture(integer(), map()) :: CollectionDecision.t()
  def collection_decision_fixture(session_id, attrs \\ %{}) do
    default_attrs = %{
      track_id: "track_#{System.unique_integer([:positive])}",
      track_name: "Test Track",
      artist: "Test Artist",
      position: 0,
      decision: :kept
    }

    {:ok, decision} = CollectionDecision.decide(session_id, Map.merge(default_attrs, attrs))
    decision
  end
end
