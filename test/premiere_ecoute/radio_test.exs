defmodule PremiereEcoute.RadioTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Radio
  alias PremiereEcoute.Radio.RadioTrack

  describe "insert_track/3" do
    test "stores a track for a user" do
      user = user_fixture()

      track_data = %{
        provider_ids: %{spotify: "spotify:track:123"},
        name: "Test Song",
        artist: "Test Artist",
        album: "Test Album",
        duration_ms: 180_000,
        started_at: DateTime.utc_now()
      }

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %RadioTrack{} = track} = Radio.insert_track(user.id, "spotify", track_data)
        assert track.user_id == user.id
        assert track.provider_ids == %{spotify: "spotify:track:123"}
        assert track.name == "Test Song"
        assert track.artist == "Test Artist"
        assert track.album == "Test Album"
        assert track.duration_ms == 180_000
      end)
    end
  end

  describe "get_tracks/2" do
    test "retrieves tracks for a user on a specific date" do
      user = user_fixture()
      date = ~D[2026-02-17]

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _track1} =
          Radio.insert_track(user.id, "spotify", %{
            provider_ids: %{spotify: "spotify:track:1"},
            name: "Song 1",
            artist: "Artist 1",
            started_at: DateTime.new!(date, ~T[10:00:00], "Etc/UTC")
          })

        {:ok, _track2} =
          Radio.insert_track(user.id, "spotify", %{
            provider_ids: %{spotify: "spotify:track:2"},
            name: "Song 2",
            artist: "Artist 2",
            started_at: DateTime.new!(date, ~T[11:00:00], "Etc/UTC")
          })

        # Track on a different date (should be excluded)
        {:ok, _track3} =
          Radio.insert_track(user.id, "spotify", %{
            provider_ids: %{spotify: "spotify:track:3"},
            name: "Song 3",
            artist: "Artist 3",
            started_at: DateTime.new!(~D[2026-02-18], ~T[10:00:00], "Etc/UTC")
          })
      end)

      tracks = Radio.get_tracks(user.id, date)

      assert length(tracks) == 2
      assert Enum.at(tracks, 0).provider_ids == %{spotify: "spotify:track:1"}
      assert Enum.at(tracks, 1).provider_ids == %{spotify: "spotify:track:2"}
    end
  end

  describe "consecutive duplicate prevention" do
    test "prevents inserting the same track twice in a row" do
      user = user_fixture()

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _track1} =
          Radio.insert_track(user.id, "spotify", %{
            provider_ids: %{spotify: "spotify:track:123"},
            name: "Same Song",
            artist: "Same Artist",
            started_at: DateTime.utc_now()
          })

        assert {:error, :consecutive_duplicate} =
                 Radio.insert_track(user.id, "spotify", %{
                   provider_ids: %{spotify: "spotify:track:123"},
                   name: "Same Song",
                   artist: "Same Artist",
                   started_at: DateTime.utc_now()
                 })
      end)
    end

    test "allows inserting the same track if it's not consecutive" do
      user = user_fixture()
      now = DateTime.utc_now()

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _track1} =
          Radio.insert_track(user.id, "spotify", %{
            provider_ids: %{spotify: "spotify:track:123"},
            name: "Song A",
            artist: "Artist A",
            started_at: now
          })

        {:ok, _track2} =
          Radio.insert_track(user.id, "spotify", %{
            provider_ids: %{spotify: "spotify:track:456"},
            name: "Song B",
            artist: "Artist B",
            started_at: DateTime.add(now, 1, :second)
          })

        assert {:ok, _track3} =
                 Radio.insert_track(user.id, "spotify", %{
                   provider_ids: %{spotify: "spotify:track:123"},
                   name: "Song A",
                   artist: "Artist A",
                   started_at: DateTime.add(now, 2, :second)
                 })
      end)
    end
  end

  describe "delete_tracks_before/2" do
    test "deletes tracks older than cutoff datetime" do
      user = user_fixture()
      cutoff = DateTime.utc_now()

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _old_track} =
          Radio.insert_track(user.id, "spotify", %{
            provider_ids: %{spotify: "spotify:track:old"},
            name: "Old Song",
            artist: "Old Artist",
            started_at: DateTime.add(cutoff, -1, :day)
          })

        {:ok, recent_track} =
          Radio.insert_track(user.id, "spotify", %{
            provider_ids: %{spotify: "spotify:track:recent"},
            name: "Recent Song",
            artist: "Recent Artist",
            started_at: DateTime.add(cutoff, 1, :hour)
          })

        {deleted_count, _} = Radio.delete_tracks_before(user.id, cutoff)

        assert deleted_count == 1

        date = DateTime.to_date(recent_track.started_at)
        tracks = Radio.get_tracks(user.id, date)
        assert length(tracks) == 1
        assert Enum.at(tracks, 0).provider_ids == %{spotify: "spotify:track:recent"}
      end)
    end
  end
end
