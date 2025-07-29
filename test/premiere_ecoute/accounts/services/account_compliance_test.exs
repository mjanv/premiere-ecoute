defmodule PremiereEcoute.Accounts.Services.AccountComplianceTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.Services.AccountCompliance
  alias PremiereEcoute.Accounts.User.Follow
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession

  setup do
    streamer = user_fixture(%{role: :streamer, twitch_user_id: "streamer123", twitch_username: "streamer"})
    viewer = user_fixture(%{role: :viewer, twitch_user_id: "viewer456", twitch_username: "viewer"})
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
    test "do nothing", %{viewer: viewer} do
      {:ok, data} = AccountCompliance.download_associated_data(Scope.for_user(viewer))

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
               "twitch_user_id" => "viewer456",
               "twitch_username" => "viewer"
             } = profile

      assert [
               %{
                 "twitch_user_id" => "streamer123",
                 "twitch_username" => "streamer"
               }
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

      assert [
               %{
                 "details" => %{"twitch_user_id" => "viewer456"},
                 "event_id" => _,
                 "event_type" => "AccountCreated",
                 "timestamp" => _
               },
               %{
                 "details" => %{"streamer_id" => _},
                 "event_id" => _,
                 "event_type" => "ChannelFollowed",
                 "timestamp" => _
               }
             ] = events
    end
  end
end
