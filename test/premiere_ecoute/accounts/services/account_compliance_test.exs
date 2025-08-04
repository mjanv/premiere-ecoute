defmodule PremiereEcoute.Accounts.Services.AccountComplianceTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Follow
  alias PremiereEcoute.Accounts.User.Token
  alias PremiereEcoute.Events.AccountDeleted
  alias PremiereEcoute.Events.PersonalDataRequested
  alias PremiereEcoute.EventStore
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Vote

  setup do
    streamer =
      user_fixture(%{
        role: :streamer,
        twitch: %{user_id: "streamer123", username: "streamer"},
        spotify: %{user_id: "streamer123", username: "streamer"}
      })

    viewer =
      user_fixture(%{
        role: :viewer,
        twitch: %{user_id: "viewer456", username: "viewer"},
        spotify: %{user_id: "viewer456", username: "viewer"}
      })

    {:ok, _} = Follow.follow(viewer, streamer)

    albums =
      for id <- ["7aJuG4TFXa2hmE4z1yxc3n", "5tzRuO6GP7WRvP3rEOPAO9"] do
        {:ok, album} = Album.create(spotify_album_fixture(id))
        album
      end

    sessions =
      for album <- albums do
        {:ok, session} = ListeningSession.create(%{user_id: streamer.id, album_id: album.id})
        {:ok, session} = ListeningSession.start(session)
        {:ok, session} = ListeningSession.next_track(session)
        session
      end

    for session <- sessions do
      vote(streamer, session)
      vote(viewer, session)
    end

    %{streamer: streamer, viewer: viewer, sessions: sessions, albums: albums}
  end

  describe "download_associated_data/1" do
    test "download viewer data as JSON", %{viewer: viewer} do
      {:ok, data} = Accounts.download_associated_data(Scope.for_user(viewer))

      data = Jason.decode!(data)

      assert %{
               "metadata" => metadata,
               "data" => %{
                 "profile" => profile,
                 "activity" => %{
                   "follows" => follows,
                   "votes" => votes
                 }
               },
               "events" => events
             } = data

      assert %{
               "generated_at" => _,
               "host" => "localhost",
               "version" => "0.1.0"
             } = metadata

      assert %{
               "email" => _,
               "id" => _,
               "role" => "viewer",
               "twitch" => %{
                 "user_id" => "viewer456",
                 "username" => "viewer"
               }
             } = profile

      assert [
               %{"id" => _}
             ] = follows

      assert [
               %{
                 "inserted_at" => _,
                 "session_id" => _,
                 "track_id" => _,
                 "value" => _
               },
               %{
                 "inserted_at" => _,
                 "session_id" => _,
                 "track_id" => _,
                 "value" => _
               }
             ] = votes

      # AccountCreated, AccountAssociated events are NOT generated during tests.
      # It is due to the test setup skipping event store writes in order to keep faster tests.
      # Those events will be generated in a production environment.
      assert [
               %{
                 "details" => %{"streamer_id" => _},
                 "event_id" => _,
                 "event_type" => "ChannelFollowed",
                 "timestamp" => _
               }
             ] = events
    end

    test "register an event", %{viewer: viewer} do
      {:ok, _} = Accounts.download_associated_data(Scope.for_user(viewer))

      assert %PersonalDataRequested{result: "ok"} = EventStore.last("user-#{viewer.id}")
    end
  end

  describe "delete_account/1" do
    test "delete a viewer account", %{viewer: viewer} do
      {:ok, deleted_user} = Accounts.delete_account(Scope.for_user(viewer))

      assert deleted_user.id == viewer.id
      assert is_nil(User.get(viewer.id))

      assert Enum.empty?(Token.all(where: [user_id: viewer.id], order_by: [:id]))
      assert Enum.empty?(Follow.all(where: [user_id: viewer.id]))
      assert Enum.empty?(Follow.all(where: [streamer_id: viewer.id]))
      assert Enum.empty?(Vote.all(where: [viewer_id: viewer.twitch.user_id]))
      assert Enum.empty?(ListeningSession.all(where: [user_id: viewer.id]))

      assert %AccountDeleted{} = EventStore.last("user-#{viewer.id}")
    end

    test "delete a streamer account", %{streamer: streamer} do
      {:ok, deleted_user} = Accounts.delete_account(Scope.for_user(streamer))

      assert deleted_user.id == streamer.id
      assert is_nil(User.get(streamer.id))

      assert Enum.empty?(Token.all(where: [user_id: streamer.id], order_by: [:id]))
      assert Enum.empty?(Follow.all(where: [user_id: streamer.id]))
      assert Enum.empty?(Follow.all(where: [streamer_id: streamer.id]))
      assert Enum.empty?(Vote.all(where: [viewer_id: streamer.twitch.user_id]))
      assert Enum.empty?(ListeningSession.all(where: [user_id: streamer.id]))

      assert %AccountDeleted{} = EventStore.last("user-#{streamer.id}")
    end

    test "deleting non-existent user raises appropriate error" do
      user = user_fixture(%{role: :viewer, twitch: %{user_id: "test123"}})
      Repo.delete!(user)

      assert_raise Ecto.StaleEntryError, fn -> Accounts.delete_account(Scope.for_user(user)) end
    end
  end
end
