defmodule PremiereEcoute.Radio.Workers.CleanupOldTracksTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Radio
  alias PremiereEcoute.Radio.Workers.CleanupOldTracks

  defp track_attrs(spotify_id, started_at) do
    %{provider_ids: %{spotify: spotify_id}, name: "Song", artist: "Artist", started_at: started_at}
  end

  defp enable_radio_tracking(user, retention_days: retention_days) do
    {:ok, user} =
      User.edit_user_profile(user, %{
        radio_settings: %{enabled: true, retention_days: retention_days}
      })

    user
  end

  describe "perform/1" do
    test "deletes tracks older than retention period for enabled streamers" do
      user = user_fixture(%{role: :streamer})
      enable_radio_tracking(user, retention_days: 7)

      old_started_at = DateTime.add(DateTime.utc_now(), -8, :day) |> DateTime.truncate(:second)

      Oban.Testing.with_testing_mode(:manual, fn ->
        Radio.insert_track(user.id, "spotify", track_attrs("track:old", old_started_at))
      end)

      assert :ok = perform_job(CleanupOldTracks, %{})

      assert Radio.get_tracks(user.id, DateTime.to_date(old_started_at)) == []
    end

    test "keeps tracks within the retention period" do
      user = user_fixture(%{role: :streamer})
      enable_radio_tracking(user, retention_days: 7)

      recent_started_at = DateTime.add(DateTime.utc_now(), -3, :day) |> DateTime.truncate(:second)

      Oban.Testing.with_testing_mode(:manual, fn ->
        Radio.insert_track(user.id, "spotify", track_attrs("track:recent", recent_started_at))
      end)

      assert :ok = perform_job(CleanupOldTracks, %{})

      assert [track] = Radio.get_tracks(user.id, DateTime.to_date(recent_started_at))
      assert track.provider_ids == %{spotify: "track:recent"}
    end

    test "does not delete tracks for users with tracking disabled" do
      user = user_fixture(%{role: :streamer})

      old_started_at = DateTime.add(DateTime.utc_now(), -8, :day) |> DateTime.truncate(:second)

      Oban.Testing.with_testing_mode(:manual, fn ->
        Radio.insert_track(user.id, "spotify", track_attrs("track:old", old_started_at))
      end)

      assert :ok = perform_job(CleanupOldTracks, %{})

      assert [_track] = Radio.get_tracks(user.id, DateTime.to_date(old_started_at))
    end
  end
end
